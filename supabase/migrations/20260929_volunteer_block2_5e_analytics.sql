-- ============================================================================
-- SPATIALLY VOLUNTEER BLOCK 2.5E: OPERATIONAL HEALTH & ANALYTICS
-- Migration: 20260929_volunteer_block2_5e_analytics.sql
-- Description: Indexes and authoritative RPCs for event operational health,
--              zone health, response time metrics, and event timeline.
-- ============================================================================

-- Additional composite indexes for fast event-scoped timeline and metrics retrieval
CREATE INDEX IF NOT EXISTS idx_coverage_requests_event_created 
  ON public.coverage_requests USING btree (event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_supervisor_tasks_event_created 
  ON public.supervisor_tasks USING btree (event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_shift_handoffs_event_created 
  ON public.shift_handoffs USING btree (event_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- Authoritative RPC: get_event_operational_health
-- Computes aggregated operational status across incidents, assistance, coverage,
-- tasks, shifts, communications, zones, and lost & found for a specific event.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_event_operational_health(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_staff BOOLEAN;
    v_result JSONB;
BEGIN
    SELECT public.is_event_staff(p_event_id) INTO v_is_staff;
    IF NOT v_is_staff THEN
        RAISE EXCEPTION 'Access denied: not staff for event %', p_event_id;
    END IF;

    SELECT jsonb_build_object(
        'event_id', p_event_id,
        'computed_at', NOW(),
        'incidents', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'active', COUNT(*) FILTER (WHERE status IN ('reported', 'acknowledged', 'assigned', 'in_progress')),
                'urgent', COUNT(*) FILTER (WHERE priority = 'urgent' AND status NOT IN ('resolved', 'closed')),
                'resolved', COUNT(*) FILTER (WHERE status IN ('resolved', 'closed')),
                'by_category', (
                    SELECT COALESCE(jsonb_object_agg(category, cat_count), '{}'::jsonb)
                    FROM (
                        SELECT category, COUNT(*) as cat_count
                        FROM public.operational_incidents
                        WHERE event_id = p_event_id
                        GROUP BY category
                    ) c
                ),
                'avg_time_to_acknowledge_seconds', ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (acknowledged_at - created_at))) FILTER (WHERE acknowledged_at IS NOT NULL), 0)),
                'avg_time_to_assign_seconds', ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (assigned_at - created_at))) FILTER (WHERE assigned_at IS NOT NULL), 0)),
                'avg_time_to_resolve_seconds', ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))) FILTER (WHERE resolved_at IS NOT NULL), 0))
            )
            FROM public.operational_incidents
            WHERE event_id = p_event_id
        ),
        'assistance', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'pending', COUNT(*) FILTER (WHERE status IN ('reported', 'acknowledged')),
                'in_progress', COUNT(*) FILTER (WHERE status IN ('assigned', 'in_progress')),
                'resolved', COUNT(*) FILTER (WHERE status IN ('resolved', 'closed')),
                'avg_time_to_resolve_seconds', ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))) FILTER (WHERE resolved_at IS NOT NULL), 0))
            )
            FROM public.operational_incidents
            WHERE event_id = p_event_id AND (category = 'assistance' OR reporter_type = 'attendee')
        ),
        'coverage', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'pending', COUNT(*) FILTER (WHERE status = 'pending'),
                'accepted', COUNT(*) FILTER (WHERE status = 'accepted'),
                'resolved', COUNT(*) FILTER (WHERE status = 'resolved'),
                'avg_time_to_accept_seconds', ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (accepted_at - created_at))) FILTER (WHERE accepted_at IS NOT NULL), 0))
            )
            FROM public.coverage_requests
            WHERE event_id = p_event_id
        ),
        'tasks', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'pending', COUNT(*) FILTER (WHERE status = 'pending'),
                'in_progress', COUNT(*) FILTER (WHERE status = 'in_progress'),
                'completed', COUNT(*) FILTER (WHERE status = 'completed'),
                'avg_time_to_complete_seconds', ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) FILTER (WHERE completed_at IS NOT NULL), 0))
            )
            FROM public.supervisor_tasks
            WHERE event_id = p_event_id
        ),
        'shifts', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'active', COUNT(*) FILTER (WHERE status = 'active'),
                'on_break', COUNT(*) FILTER (WHERE status = 'active' AND break_state = 'taking_break'),
                'completed', COUNT(*) FILTER (WHERE status = 'completed')
            )
            FROM public.volunteer_shifts
            WHERE event_id = p_event_id
        ),
        'communications', (
            SELECT jsonb_build_object(
                'total_messages', COUNT(*),
                'broadcasts', COUNT(*) FILTER (WHERE target_type = 'broadcast'),
                'urgent', COUNT(*) FILTER (WHERE priority = 'urgent')
            )
            FROM public.operational_messages
            WHERE event_id = p_event_id
        ),
        'zones', (
            SELECT COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'zone_id', ez.id,
                            'zone_name', ez.name,
                            'floor_level', ez.floor_level,
                            'capacity_limit', ez.capacity_limit,
                            'operating_capacity', ez.operating_capacity,
                            'current_density', ez.current_density,
                            'is_monitored', ez.is_crowd_monitored,
                            'active_count', COALESCE(vc.active_count, 0),
                            'count_updated_at', vc.updated_at,
                            'active_incidents', (
                                SELECT COUNT(*) FROM public.operational_incidents oi
                                WHERE oi.event_id = p_event_id 
                                  AND (oi.zone_id = ez.id OR oi.venue_zone_name = ez.name)
                                  AND oi.status IN ('reported', 'acknowledged', 'assigned', 'in_progress')
                            ),
                            'pending_tasks', (
                                SELECT COUNT(*) FROM public.supervisor_tasks st
                                WHERE st.event_id = p_event_id 
                                  AND (st.zone_id = ez.id OR st.zone_name = ez.name)
                                  AND st.status IN ('pending', 'in_progress')
                            ),
                            'active_staff', (
                                SELECT COUNT(*) FROM public.volunteer_shifts vs
                                WHERE vs.event_id = p_event_id 
                                  AND (vs.zone_id = ez.id OR vs.zone_name = ez.name)
                                  AND vs.status = 'active'
                            ),
                            'coverage_needed', EXISTS (
                                SELECT 1 FROM public.coverage_requests cr
                                WHERE cr.event_id = p_event_id 
                                  AND (cr.zone_id = ez.id OR cr.zone_name = ez.name)
                                  AND cr.status = 'pending'
                            )
                        )
                    )
                    FROM public.event_zones ez
                    LEFT JOIN public.volunteer_counts vc 
                      ON (vc.event_id = p_event_id AND vc.zone = ez.name)
                    WHERE ez.event_id = p_event_id
                ),
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'zone_id', z.elem,
                            'zone_name', z.elem,
                            'floor_level', 1,
                            'capacity_limit', 200,
                            'operating_capacity', 200,
                            'current_density', 'low',
                            'is_monitored', true,
                            'active_count', COALESCE(vc.active_count, 0),
                            'count_updated_at', vc.updated_at,
                            'active_incidents', (
                                SELECT COUNT(*) FROM public.operational_incidents oi
                                WHERE oi.event_id = p_event_id 
                                  AND (oi.venue_zone_name = z.elem)
                                  AND oi.status IN ('reported', 'acknowledged', 'assigned', 'in_progress')
                            ),
                            'pending_tasks', (
                                SELECT COUNT(*) FROM public.supervisor_tasks st
                                WHERE st.event_id = p_event_id 
                                  AND (st.zone_name = z.elem)
                                  AND st.status IN ('pending', 'in_progress')
                            ),
                            'active_staff', (
                                SELECT COUNT(*) FROM public.volunteer_shifts vs
                                WHERE vs.event_id = p_event_id 
                                  AND (vs.zone_name = z.elem)
                                  AND vs.status = 'active'
                            ),
                            'coverage_needed', EXISTS (
                                SELECT 1 FROM public.coverage_requests cr
                                WHERE cr.event_id = p_event_id 
                                  AND (cr.zone_name = z.elem)
                                  AND cr.status = 'pending'
                            )
                        )
                    )
                    FROM public.events e,
                         LATERAL unnest(e.zones) AS z(elem)
                    LEFT JOIN public.volunteer_counts vc 
                      ON (vc.event_id = p_event_id AND vc.zone = z.elem)
                    WHERE e.id = p_event_id
                ),
                '[]'::jsonb
            )
        ),
        'lost_found', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'lost', COUNT(*) FILTER (WHERE report_type = 'lost'),
                'found', COUNT(*) FILTER (WHERE report_type = 'found'),
                'active', COUNT(*) FILTER (WHERE status = 'open'),
                'resolved', COUNT(*) FILTER (WHERE status IN ('claimed', 'returned'))
            )
            FROM public.lost_found_reports
            WHERE event_id = p_event_id
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_event_operational_health(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_event_operational_health(UUID) TO anon;

-- ----------------------------------------------------------------------------
-- Authoritative RPC: get_event_operational_timeline
-- Returns chronological operational milestones across all domains.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_event_operational_timeline(p_event_id UUID, p_limit INTEGER DEFAULT 50)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_staff BOOLEAN;
    v_result JSONB;
BEGIN
    SELECT public.is_event_staff(p_event_id) INTO v_is_staff;
    IF NOT v_is_staff THEN
        RAISE EXCEPTION 'Access denied: not staff for event %', p_event_id;
    END IF;

    WITH timeline_events AS (
        SELECT 
            'inc_created_' || id::text as id,
            'incident' as source_type,
            id::text as source_id,
            'created' as event_type,
            'Incident: ' || title as title,
            description,
            created_at as timestamp,
            zone_id,
            venue_zone_name as zone_name,
            reporter_name as actor_name,
            priority,
            '/incident_detail' as action_route,
            jsonb_build_object('incidentId', id::text) as action_payload
        FROM public.operational_incidents
        WHERE event_id = p_event_id

        UNION ALL

        SELECT 
            'inc_resolved_' || id::text as id,
            'incident' as source_type,
            id::text as source_id,
            'resolved' as event_type,
            'Incident Resolved: ' || title as title,
            COALESCE(resolution_notes, 'Marked resolved by staff') as description,
            resolved_at as timestamp,
            zone_id,
            venue_zone_name as zone_name,
            assigned_to_name as actor_name,
            priority,
            '/incident_detail' as action_route,
            jsonb_build_object('incidentId', id::text) as action_payload
        FROM public.operational_incidents
        WHERE event_id = p_event_id AND resolved_at IS NOT NULL

        UNION ALL

        SELECT 
            'cov_created_' || id::text as id,
            'coverage' as source_type,
            id::text as source_id,
            'created' as event_type,
            'Relief Requested by ' || requester_name as title,
            reason as description,
            created_at as timestamp,
            zone_id,
            zone_name,
            requester_name as actor_name,
            priority,
            '/team_overview' as action_route,
            jsonb_build_object('requestId', id::text) as action_payload
        FROM public.coverage_requests
        WHERE event_id = p_event_id

        UNION ALL

        SELECT 
            'task_created_' || id::text as id,
            'task' as source_type,
            id::text as source_id,
            'created' as event_type,
            'Task Assigned: ' || title as title,
            description,
            created_at as timestamp,
            zone_id,
            zone_name,
            supervisor_name as actor_name,
            priority,
            '/supervisor_tasks' as action_route,
            jsonb_build_object('taskId', id::text) as action_payload
        FROM public.supervisor_tasks
        WHERE event_id = p_event_id

        UNION ALL

        SELECT 
            'task_completed_' || id::text as id,
            'task' as source_type,
            id::text as source_id,
            'completed' as event_type,
            'Task Completed: ' || title as title,
            COALESCE(completion_notes, 'Task marked completed') as description,
            completed_at as timestamp,
            zone_id,
            zone_name,
            assigned_to_name as actor_name,
            priority,
            '/supervisor_tasks' as action_route,
            jsonb_build_object('taskId', id::text) as action_payload
        FROM public.supervisor_tasks
        WHERE event_id = p_event_id AND completed_at IS NOT NULL

        UNION ALL

        SELECT 
            'shift_start_' || id::text as id,
            'shift' as source_type,
            id::text as source_id,
            'started' as event_type,
            'Shift Active: ' || shift_name as title,
            'Volunteer shift commenced' as description,
            COALESCE(actual_start, scheduled_start) as timestamp,
            zone_id,
            zone_name,
            NULL as actor_name,
            'normal' as priority,
            '/shift_overview' as action_route,
            jsonb_build_object('shiftId', id::text) as action_payload
        FROM public.volunteer_shifts
        WHERE event_id = p_event_id AND (status = 'active' OR actual_start IS NOT NULL)

        UNION ALL

        SELECT 
            'msg_broadcast_' || id::text as id,
            'communication' as source_type,
            id::text as source_id,
            'broadcast' as event_type,
            'Broadcast from ' || sender_name as title,
            body as description,
            created_at as timestamp,
            zone_id,
            NULL as zone_name,
            sender_name as actor_name,
            priority,
            '/communications' as action_route,
            jsonb_build_object('messageId', id::text) as action_payload
        FROM public.operational_messages
        WHERE event_id = p_event_id AND target_type = 'broadcast'
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT * FROM timeline_events
        ORDER BY timestamp DESC
        LIMIT p_limit
    ) t;

    RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_event_operational_timeline(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_event_operational_timeline(UUID, INTEGER) TO anon;
