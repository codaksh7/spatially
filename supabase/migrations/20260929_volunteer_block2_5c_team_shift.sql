-- ============================================================================
-- SPATIALLY — VOLUNTEER BLOCK 2.5C: TEAM, SHIFT & SUPERVISOR OPERATIONS
-- Migration: 20260929_volunteer_block2_5c_team_shift.sql
-- ============================================================================

-- 1. TEAMS TABLE
CREATE TABLE IF NOT EXISTS public.event_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    lead_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    zone_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_event_teams_event ON public.event_teams(event_id);
CREATE INDEX IF NOT EXISTS idx_event_teams_lead ON public.event_teams(lead_id);

-- 2. TEAM MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.event_team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.event_teams(id) ON DELETE CASCADE,
    volunteer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'lead', 'supervisor')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE (team_id, volunteer_id)
);

CREATE INDEX IF NOT EXISTS idx_event_team_members_team ON public.event_team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_event_team_members_volunteer ON public.event_team_members(volunteer_id);

-- 3. VOLUNTEER SHIFTS TABLE
CREATE TABLE IF NOT EXISTS public.volunteer_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    volunteer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    team_id UUID REFERENCES public.event_teams(id) ON DELETE SET NULL,
    supervisor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    zone_name TEXT,
    shift_name TEXT NOT NULL DEFAULT 'Operational Shift',
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    actual_start TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'on_break', 'handoff_pending', 'completed', 'cancelled')),
    break_state TEXT NOT NULL DEFAULT 'none' CHECK (break_state IN ('none', 'requested', 'on_break', 'completed')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_volunteer_shifts_event ON public.volunteer_shifts(event_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_shifts_volunteer ON public.volunteer_shifts(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_shifts_status ON public.volunteer_shifts(status);
CREATE INDEX IF NOT EXISTS idx_volunteer_shifts_team ON public.volunteer_shifts(team_id);

-- 4. SHIFT BREAKS TABLE
CREATE TABLE IF NOT EXISTS public.shift_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID NOT NULL REFERENCES public.volunteer_shifts(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    volunteer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expected_return TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_shift_breaks_shift ON public.shift_breaks(shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_breaks_volunteer ON public.shift_breaks(volunteer_id);

-- 5. COVERAGE / RELIEF REQUESTS TABLE
CREATE TABLE IF NOT EXISTS public.coverage_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    shift_id UUID REFERENCES public.volunteer_shifts(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    requester_name TEXT NOT NULL,
    team_id UUID REFERENCES public.event_teams(id) ON DELETE SET NULL,
    team_name TEXT,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    zone_name TEXT,
    reason TEXT NOT NULL CHECK (reason IN ('break', 'incident', 'equipment', 'overflow', 'personal', 'other')),
    notes TEXT,
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'declined', 'cancelled', 'completed')),
    covering_volunteer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    covering_volunteer_name TEXT,
    accepted_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_coverage_requests_event ON public.coverage_requests(event_id);
CREATE INDEX IF NOT EXISTS idx_coverage_requests_requester ON public.coverage_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_coverage_requests_status ON public.coverage_requests(status);

-- 6. SUPERVISOR TASKS TABLE
CREATE TABLE IF NOT EXISTS public.supervisor_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    team_id UUID REFERENCES public.event_teams(id) ON DELETE SET NULL,
    team_name TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    assigned_to_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_to_name TEXT NOT NULL,
    supervisor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    supervisor_name TEXT NOT NULL,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    zone_name TEXT,
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'accepted', 'in_progress', 'completed', 'cancelled')),
    due_time TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    completion_notes TEXT,
    linked_incident_id UUID REFERENCES public.operational_incidents(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_supervisor_tasks_event ON public.supervisor_tasks(event_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_tasks_assigned_to ON public.supervisor_tasks(assigned_to_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_tasks_supervisor ON public.supervisor_tasks(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_tasks_status ON public.supervisor_tasks(status);

-- 7. SHIFT HANDOFFS TABLE
CREATE TABLE IF NOT EXISTS public.shift_handoffs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    shift_id UUID NOT NULL REFERENCES public.volunteer_shifts(id) ON DELETE CASCADE,
    outgoing_volunteer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    outgoing_volunteer_name TEXT NOT NULL,
    incoming_volunteer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    incoming_volunteer_name TEXT,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    zone_name TEXT,
    operational_summary TEXT NOT NULL,
    equipment_condition TEXT,
    attendee_notes TEXT,
    unresolved_incident_ids JSONB DEFAULT '[]'::jsonb,
    pending_task_ids JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'acknowledged', 'completed')),
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_shift_handoffs_event ON public.shift_handoffs(event_id);
CREATE INDEX IF NOT EXISTS idx_shift_handoffs_outgoing ON public.shift_handoffs(outgoing_volunteer_id);
CREATE INDEX IF NOT EXISTS idx_shift_handoffs_incoming ON public.shift_handoffs(incoming_volunteer_id);

-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.event_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteer_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_breaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coverage_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_handoffs ENABLE ROW LEVEL SECURITY;

-- Helper function to check if caller is assigned staff to event
CREATE OR REPLACE FUNCTION public.is_event_staff(p_event_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.volunteer_assignments va
        WHERE va.volunteer_id = auth.uid()
          AND va.event_id = p_event_id
          AND va.status = 'active'
    ) OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role IN ('organizer', 'admin')
    );
$$;

-- RLS: event_teams
CREATE POLICY "Staff can view event teams"
    ON public.event_teams FOR SELECT
    USING (public.is_event_staff(event_id));

CREATE POLICY "Organizers can manage event teams"
    ON public.event_teams FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
        )
    );

-- RLS: event_team_members
CREATE POLICY "Staff can view team members"
    ON public.event_team_members FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.event_teams et
            WHERE et.id = event_team_members.team_id
              AND public.is_event_staff(et.event_id)
        )
    );

CREATE POLICY "Organizers and leads can manage team members"
    ON public.event_team_members FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
        ) OR EXISTS (
            SELECT 1 FROM public.event_teams et
            WHERE et.id = event_team_members.team_id
              AND et.lead_id = auth.uid()
        )
    );

-- RLS: volunteer_shifts
CREATE POLICY "Staff can view event shifts"
    ON public.volunteer_shifts FOR SELECT
    USING (public.is_event_staff(event_id));

CREATE POLICY "Volunteers can update own shift"
    ON public.volunteer_shifts FOR UPDATE
    USING (volunteer_id = auth.uid() OR public.is_event_staff(event_id));

CREATE POLICY "Organizers can insert shifts"
    ON public.volunteer_shifts FOR INSERT
    WITH CHECK (public.is_event_staff(event_id));

-- RLS: shift_breaks
CREATE POLICY "Staff can view breaks"
    ON public.shift_breaks FOR SELECT
    USING (public.is_event_staff(event_id));

CREATE POLICY "Volunteers can manage own breaks"
    ON public.shift_breaks FOR ALL
    USING (volunteer_id = auth.uid());

-- RLS: coverage_requests
CREATE POLICY "Staff can view coverage requests"
    ON public.coverage_requests FOR SELECT
    USING (public.is_event_staff(event_id));

CREATE POLICY "Staff can insert coverage requests"
    ON public.coverage_requests FOR INSERT
    WITH CHECK (public.is_event_staff(event_id));

CREATE POLICY "Staff can update coverage requests"
    ON public.coverage_requests FOR UPDATE
    USING (public.is_event_staff(event_id));

-- RLS: supervisor_tasks
CREATE POLICY "Staff can view assigned or team tasks"
    ON public.supervisor_tasks FOR SELECT
    USING (public.is_event_staff(event_id));

CREATE POLICY "Supervisors and assigned volunteers can update tasks"
    ON public.supervisor_tasks FOR UPDATE
    USING (public.is_event_staff(event_id));

CREATE POLICY "Supervisors can insert tasks"
    ON public.supervisor_tasks FOR INSERT
    WITH CHECK (public.is_event_staff(event_id));

-- RLS: shift_handoffs
CREATE POLICY "Staff can view shift handoffs"
    ON public.shift_handoffs FOR SELECT
    USING (public.is_event_staff(event_id));

CREATE POLICY "Volunteers can create and update handoffs"
    ON public.shift_handoffs FOR ALL
    USING (public.is_event_staff(event_id));

-- ============================================================================
-- 9. RPCs / DATABASE FUNCTIONS FOR BLOCK 2.5C
-- ============================================================================

-- RPC 1: Start Shift
CREATE OR REPLACE FUNCTION public.start_volunteer_shift(
    p_shift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_shift public.volunteer_shifts;
    v_result JSONB;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_shift
    FROM public.volunteer_shifts
    WHERE id = p_shift_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Shift not found.');
    END IF;

    -- Verify caller owns shift or is organizer/admin
    IF v_shift.volunteer_id <> v_caller_id AND NOT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = v_caller_id AND role IN ('organizer', 'admin')
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Cannot start another volunteer''s shift.');
    END IF;

    IF v_shift.status = 'active' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Shift is already active.', 'shift_id', v_shift.id);
    END IF;

    IF v_shift.status IN ('completed', 'cancelled') THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_STATE', 'message', 'Shift is already completed or cancelled.');
    END IF;

    UPDATE public.volunteer_shifts
    SET status = 'active',
        actual_start = COALESCE(actual_start, timezone('utc'::text, now())),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_shift_id
    RETURNING to_jsonb(volunteer_shifts.*) INTO v_result;

    RETURN jsonb_build_object('success', true, 'shift', v_result);
END;
$$;

-- RPC 2: End Shift
CREATE OR REPLACE FUNCTION public.end_volunteer_shift(
    p_shift_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_shift public.volunteer_shifts;
    v_active_tasks INT := 0;
    v_active_incidents INT := 0;
    v_result JSONB;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_shift
    FROM public.volunteer_shifts
    WHERE id = p_shift_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Shift not found.');
    END IF;

    IF v_shift.volunteer_id <> v_caller_id AND NOT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = v_caller_id AND role IN ('organizer', 'admin')
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Cannot end another volunteer''s shift.');
    END IF;

    IF v_shift.status = 'completed' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Shift is already completed.', 'shift_id', v_shift.id);
    END IF;

    -- Count active tasks
    SELECT COUNT(*) INTO v_active_tasks
    FROM public.supervisor_tasks
    WHERE assigned_to_id = v_shift.volunteer_id
      AND event_id = v_shift.event_id
      AND status IN ('assigned', 'accepted', 'in_progress');

    -- Count active incidents assigned to this volunteer
    SELECT COUNT(*) INTO v_active_incidents
    FROM public.operational_incidents
    WHERE assigned_to_id = v_shift.volunteer_id
      AND event_id = v_shift.event_id
      AND status IN ('assigned', 'in_progress');

    UPDATE public.volunteer_shifts
    SET status = 'completed',
        actual_end = timezone('utc'::text, now()),
        notes = CASE WHEN p_notes IS NOT NULL THEN p_notes ELSE notes END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_shift_id
    RETURNING to_jsonb(volunteer_shifts.*) INTO v_result;

    RETURN jsonb_build_object(
        'success', true,
        'shift', v_result,
        'pending_tasks_count', v_active_tasks,
        'pending_incidents_count', v_active_incidents
    );
END;
$$;

-- RPC 3: Start Break
CREATE OR REPLACE FUNCTION public.start_shift_break(
    p_shift_id UUID,
    p_expected_return TIMESTAMPTZ DEFAULT NULL,
    p_reason TEXT DEFAULT 'Standard Break'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_shift public.volunteer_shifts;
    v_break_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_shift
    FROM public.volunteer_shifts
    WHERE id = p_shift_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Shift not found.');
    END IF;

    IF v_shift.volunteer_id <> v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Cannot start break on another volunteer''s shift.');
    END IF;

    IF v_shift.status <> 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_STATE', 'message', 'Shift must be active to start a break.');
    END IF;

    INSERT INTO public.shift_breaks (
        shift_id,
        event_id,
        volunteer_id,
        start_time,
        expected_return,
        reason
    ) VALUES (
        v_shift.id,
        v_shift.event_id,
        v_caller_id,
        timezone('utc'::text, now()),
        p_expected_return,
        p_reason
    ) RETURNING id INTO v_break_id;

    UPDATE public.volunteer_shifts
    SET status = 'on_break',
        break_state = 'on_break',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_shift_id;

    RETURN jsonb_build_object('success', true, 'break_id', v_break_id, 'shift_id', v_shift.id);
END;
$$;

-- RPC 4: End Break
CREATE OR REPLACE FUNCTION public.end_shift_break(
    p_shift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_shift public.volunteer_shifts;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_shift
    FROM public.volunteer_shifts
    WHERE id = p_shift_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Shift not found.');
    END IF;

    IF v_shift.volunteer_id <> v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Cannot end break on another volunteer''s shift.');
    END IF;

    -- Update open break record
    UPDATE public.shift_breaks
    SET end_time = timezone('utc'::text, now())
    WHERE shift_id = p_shift_id
      AND end_time IS NULL;

    UPDATE public.volunteer_shifts
    SET status = 'active',
        break_state = 'completed',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_shift_id;

    RETURN jsonb_build_object('success', true, 'shift_id', v_shift.id, 'status', 'active');
END;
$$;

-- RPC 5: Request Shift Coverage
CREATE OR REPLACE FUNCTION public.request_shift_coverage(
    p_event_id UUID,
    p_shift_id UUID,
    p_reason TEXT,
    p_notes TEXT DEFAULT NULL,
    p_priority TEXT DEFAULT 'normal'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_name TEXT;
    v_shift public.volunteer_shifts;
    v_request_id UUID;
    v_team_name TEXT;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT full_name INTO v_caller_name FROM public.profiles WHERE id = v_caller_id;
    IF v_caller_name IS NULL THEN
        v_caller_name := 'Volunteer Staff';
    END IF;

    SELECT * INTO v_shift
    FROM public.volunteer_shifts
    WHERE id = p_shift_id;

    IF v_shift.team_id IS NOT NULL THEN
        SELECT name INTO v_team_name FROM public.event_teams WHERE id = v_shift.team_id;
    END IF;

    INSERT INTO public.coverage_requests (
        event_id,
        shift_id,
        requester_id,
        requester_name,
        team_id,
        team_name,
        zone_id,
        zone_name,
        reason,
        notes,
        priority,
        status
    ) VALUES (
        p_event_id,
        p_shift_id,
        v_caller_id,
        v_caller_name,
        v_shift.team_id,
        v_team_name,
        v_shift.zone_id,
        v_shift.zone_name,
        p_reason,
        p_notes,
        p_priority,
        'requested'
    ) RETURNING id INTO v_request_id;

    RETURN jsonb_build_object('success', true, 'request_id', v_request_id);
END;
$$;

-- RPC 6: Accept Shift Coverage (Atomic with row locking)
CREATE OR REPLACE FUNCTION public.accept_shift_coverage(
    p_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_name TEXT;
    v_req public.coverage_requests;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_req
    FROM public.coverage_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Coverage request not found.');
    END IF;

    IF v_req.status <> 'requested' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ALREADY_CLAIMED',
            'message', 'This coverage request was already claimed or resolved.',
            'covering_volunteer_name', v_req.covering_volunteer_name
        );
    END IF;

    SELECT full_name INTO v_caller_name FROM public.profiles WHERE id = v_caller_id;
    IF v_caller_name IS NULL THEN
        v_caller_name := 'Volunteer Staff';
    END IF;

    UPDATE public.coverage_requests
    SET status = 'accepted',
        covering_volunteer_id = v_caller_id,
        covering_volunteer_name = v_caller_name,
        accepted_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'covering_volunteer_name', v_caller_name
    );
END;
$$;

-- RPC 7: Create Supervisor Task
CREATE OR REPLACE FUNCTION public.create_supervisor_task(
    p_event_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_assigned_to_id UUID,
    p_team_id UUID DEFAULT NULL,
    p_zone_id UUID DEFAULT NULL,
    p_priority TEXT DEFAULT 'normal',
    p_due_time TIMESTAMPTZ DEFAULT NULL,
    p_linked_incident_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_name TEXT;
    v_assigned_name TEXT;
    v_team_name TEXT;
    v_zone_name TEXT;
    v_task_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    -- Verify caller is staff for this event
    IF NOT public.is_event_staff(p_event_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Caller is not staff for this event.');
    END IF;

    SELECT full_name INTO v_caller_name FROM public.profiles WHERE id = v_caller_id;
    SELECT full_name INTO v_assigned_name FROM public.profiles WHERE id = p_assigned_to_id;

    IF v_caller_name IS NULL THEN v_caller_name := 'Supervisor'; END IF;
    IF v_assigned_name IS NULL THEN v_assigned_name := 'Volunteer'; END IF;

    IF p_team_id IS NOT NULL THEN
        SELECT name INTO v_team_name FROM public.event_teams WHERE id = p_team_id;
    END IF;

    IF p_zone_id IS NOT NULL THEN
        SELECT name INTO v_zone_name FROM public.event_zones WHERE id = p_zone_id;
    END IF;

    INSERT INTO public.supervisor_tasks (
        event_id,
        team_id,
        team_name,
        title,
        description,
        assigned_to_id,
        assigned_to_name,
        supervisor_id,
        supervisor_name,
        zone_id,
        zone_name,
        priority,
        status,
        due_time,
        linked_incident_id
    ) VALUES (
        p_event_id,
        p_team_id,
        v_team_name,
        p_title,
        p_description,
        p_assigned_to_id,
        v_assigned_name,
        v_caller_id,
        v_caller_name,
        p_zone_id,
        v_zone_name,
        p_priority,
        'assigned',
        p_due_time,
        p_linked_incident_id
    ) RETURNING id INTO v_task_id;

    RETURN jsonb_build_object('success', true, 'task_id', v_task_id);
END;
$$;

-- RPC 8: Update Task Status
CREATE OR REPLACE FUNCTION public.update_task_status(
    p_task_id UUID,
    p_status TEXT,
    p_completion_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_task public.supervisor_tasks;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_task
    FROM public.supervisor_tasks
    WHERE id = p_task_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Task not found.');
    END IF;

    -- Verify caller is assigned volunteer, supervisor, or event admin
    IF v_task.assigned_to_id <> v_caller_id AND v_task.supervisor_id <> v_caller_id AND NOT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = v_caller_id AND role IN ('organizer', 'admin')
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Not authorized to update this task.');
    END IF;

    UPDATE public.supervisor_tasks
    SET status = p_status,
        accepted_at = CASE WHEN p_status = 'accepted' AND accepted_at IS NULL THEN timezone('utc'::text, now()) ELSE accepted_at END,
        completed_at = CASE WHEN p_status = 'completed' AND completed_at IS NULL THEN timezone('utc'::text, now()) ELSE completed_at END,
        completion_notes = CASE WHEN p_completion_notes IS NOT NULL THEN p_completion_notes ELSE completion_notes END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_task_id;

    RETURN jsonb_build_object('success', true, 'task_id', p_task_id, 'status', p_status);
END;
$$;

-- RPC 9: Create Shift Handoff
CREATE OR REPLACE FUNCTION public.create_shift_handoff(
    p_shift_id UUID,
    p_summary TEXT,
    p_incoming_volunteer_id UUID DEFAULT NULL,
    p_equipment_condition TEXT DEFAULT NULL,
    p_attendee_notes TEXT DEFAULT NULL,
    p_incident_ids JSONB DEFAULT '[]'::jsonb,
    p_task_ids JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_name TEXT;
    v_incoming_name TEXT;
    v_shift public.volunteer_shifts;
    v_handoff_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_shift
    FROM public.volunteer_shifts
    WHERE id = p_shift_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Shift not found.');
    END IF;

    IF v_shift.volunteer_id <> v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN', 'message', 'Cannot create handoff for another volunteer''s shift.');
    END IF;

    SELECT full_name INTO v_caller_name FROM public.profiles WHERE id = v_caller_id;
    IF v_caller_name IS NULL THEN v_caller_name := 'Volunteer Staff'; END IF;

    IF p_incoming_volunteer_id IS NOT NULL THEN
        SELECT full_name INTO v_incoming_name FROM public.profiles WHERE id = p_incoming_volunteer_id;
    END IF;

    INSERT INTO public.shift_handoffs (
        event_id,
        shift_id,
        outgoing_volunteer_id,
        outgoing_volunteer_name,
        incoming_volunteer_id,
        incoming_volunteer_name,
        zone_id,
        zone_name,
        operational_summary,
        equipment_condition,
        attendee_notes,
        unresolved_incident_ids,
        pending_task_ids,
        status
    ) VALUES (
        v_shift.event_id,
        v_shift.id,
        v_caller_id,
        v_caller_name,
        p_incoming_volunteer_id,
        v_incoming_name,
        v_shift.zone_id,
        v_shift.zone_name,
        p_summary,
        p_equipment_condition,
        p_attendee_notes,
        p_incident_ids,
        p_task_ids,
        'pending'
    ) RETURNING id INTO v_handoff_id;

    -- Update shift status to handoff_pending
    UPDATE public.volunteer_shifts
    SET status = 'handoff_pending',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_shift_id;

    RETURN jsonb_build_object('success', true, 'handoff_id', v_handoff_id);
END;
$$;

-- RPC 10: Acknowledge Shift Handoff
CREATE OR REPLACE FUNCTION public.acknowledge_shift_handoff(
    p_handoff_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_handoff public.shift_handoffs;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Authentication required.');
    END IF;

    SELECT * INTO v_handoff
    FROM public.shift_handoffs
    WHERE id = p_handoff_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Handoff not found.');
    END IF;

    UPDATE public.shift_handoffs
    SET status = 'acknowledged',
        acknowledged_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_handoff_id;

    RETURN jsonb_build_object('success', true, 'handoff_id', p_handoff_id, 'status', 'acknowledged');
END;
$$;

-- ============================================================================
-- 10. REALTIME PUBLICATION SETUP
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'volunteer_shifts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.volunteer_shifts;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'coverage_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.coverage_requests;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'supervisor_tasks'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.supervisor_tasks;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'shift_handoffs'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shift_handoffs;
    END IF;
END $$;

-- ============================================================================
-- 11. SEED DEFAULT TEAMS & SHIFTS FOR EXISTING TEST EVENTS
-- ============================================================================

DO $$
DECLARE
    v_demo_event_id UUID := '5caca6ed-d946-4833-978e-f62209bc06ac';
    v_cultural_event_id UUID := '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301';
    v_aryan_id UUID := 'e4bdf3f5-7e8e-484a-b9e0-1af8d9db2a4d';
    v_blaise_id UUID := '49ec4fa7-f196-4c3b-8ac1-189455ef4947';
    v_team_crowd UUID;
    v_team_hall UUID;
    v_zone_auditorium UUID;
BEGIN
    -- Check if Demo Fest 2026 exists
    IF EXISTS (SELECT 1 FROM public.events WHERE id = v_demo_event_id) THEN
        -- Seed Team: Crowd Operations
        INSERT INTO public.event_teams (id, event_id, name, description, lead_id)
        VALUES (
            'a0000000-0000-0000-0000-000000000001',
            v_demo_event_id,
            'Crowd Operations',
            'Manages entry flows, corridor density, and zone monitors.',
            v_aryan_id
        ) ON CONFLICT (id) DO NOTHING;

        -- Seed Team: Hall & Stage Support
        INSERT INTO public.event_teams (id, event_id, name, description, lead_id)
        VALUES (
            'a0000000-0000-0000-0000-000000000002',
            v_demo_event_id,
            'Hall & Stage Support',
            'Manages auditorium seating, stage assistance, and queues.',
            v_blaise_id
        ) ON CONFLICT (id) DO NOTHING;

        -- Seed Memberships
        INSERT INTO public.event_team_members (team_id, volunteer_id, role)
        VALUES 
            ('a0000000-0000-0000-0000-000000000001', v_aryan_id, 'lead'),
            ('a0000000-0000-0000-0000-000000000001', v_blaise_id, 'member')
        ON CONFLICT (team_id, volunteer_id) DO NOTHING;

        -- Seed Shifts for aryan and blaise
        INSERT INTO public.volunteer_shifts (
            id,
            event_id,
            volunteer_id,
            team_id,
            supervisor_id,
            shift_name,
            scheduled_start,
            scheduled_end,
            status,
            zone_name
        ) VALUES (
            'b0000000-0000-0000-0000-000000000001',
            v_demo_event_id,
            v_aryan_id,
            'a0000000-0000-0000-0000-000000000001',
            v_blaise_id,
            'Morning Operations Shift',
            timezone('utc'::text, now()) - interval '1 hour',
            timezone('utc'::text, now()) + interval '5 hours',
            'active',
            'Entrance'
        ) ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.volunteer_shifts (
            id,
            event_id,
            volunteer_id,
            team_id,
            supervisor_id,
            shift_name,
            scheduled_start,
            scheduled_end,
            status,
            zone_name
        ) VALUES (
            'b0000000-0000-0000-0000-000000000002',
            v_demo_event_id,
            v_blaise_id,
            'a0000000-0000-0000-0000-000000000001',
            v_aryan_id,
            'Afternoon Operations Shift',
            timezone('utc'::text, now()),
            timezone('utc'::text, now()) + interval '6 hours',
            'scheduled',
            'Main Stage'
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;
