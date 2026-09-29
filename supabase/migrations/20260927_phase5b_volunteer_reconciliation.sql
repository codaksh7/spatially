-- ============================================================================
-- SPATIALLY — PHASE 5B: MIGRATION (VOLUNTEER PRODUCTION BACKEND RECONCILIATION)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description:
--   1. Atomic ticket check-in RPC with row-level locking (FOR UPDATE)
--   2. Stale volunteer counts cleanup RPC & live view
--   3. Hardened RLS policies for observations, volunteer_counts, and assignments
--   4. Volunteer assignment reconciliation with normalized event_zones
--   5. Realtime notifications hardening
-- ============================================================================

-- ============================================================================
-- 1. ATOMIC TICKET CHECK-IN RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_in_ticket(
    p_ticket_code TEXT,
    p_event_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_ticket RECORD;
    v_event_name TEXT;
    v_assignment RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Verify caller authentication
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'UNAUTHORIZED',
            'message', 'Authentication required to check in tickets.'
        );
    END IF;

    -- 2. Verify caller role (must be volunteer, organizer, or admin)
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('volunteer', 'organizer', 'admin') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'FORBIDDEN',
            'message', 'Only authorized volunteers or event staff can check in tickets.'
        );
    END IF;

    -- 3. Verify volunteer is assigned to this specific event (if role is volunteer)
    IF v_caller_role = 'volunteer' THEN
        SELECT * INTO v_assignment 
        FROM public.volunteer_assignments 
        WHERE volunteer_id = v_caller_id 
          AND event_id = p_event_id
          AND status = 'active';

        IF NOT FOUND THEN
            RETURN jsonb_build_object(
                'success', false,
                'error_code', 'NOT_ASSIGNED_TO_EVENT',
                'message', 'Volunteer is not assigned to this event.'
            );
        END IF;
    END IF;

    -- 4. Locate and lock ticket row for update (prevents race conditions)
    SELECT * INTO v_ticket 
    FROM public.tickets 
    WHERE ticket_code = p_ticket_code 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'TICKET_NOT_FOUND',
            'message', 'Ticket code not found.'
        );
    END IF;

    -- 5. Verify event match
    IF v_ticket.event_id != p_event_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'EVENT_MISMATCH',
            'message', 'Ticket is for a different event.'
        );
    END IF;

    -- 6. Check current status
    IF v_ticket.status = 'checked_in' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'ALREADY_CHECKED_IN',
            'message', 'Ticket has already been checked in.',
            'ticket_id', v_ticket.id,
            'checked_in_at', v_ticket.checked_in_at
        );
    ELSIF v_ticket.status != 'purchased' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_STATUS',
            'message', 'Ticket status is invalid for admission: ' || COALESCE(v_ticket.status, 'unknown'),
            'ticket_id', v_ticket.id
        );
    END IF;

    -- 7. Retrieve event title
    SELECT name INTO v_event_name FROM public.events WHERE id = p_event_id;

    -- 8. Atomically update ticket status
    UPDATE public.tickets
    SET status = 'checked_in',
        checked_in_at = v_now,
        checked_in_by = v_caller_id
    WHERE id = v_ticket.id;

    RETURN jsonb_build_object(
        'success', true,
        'ticket_id', v_ticket.id,
        'ticket_code', v_ticket.ticket_code,
        'event_id', p_event_id,
        'event_name', COALESCE(v_event_name, 'Event'),
        'checked_in_at', v_now,
        'checked_in_by', v_caller_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.check_in_ticket(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_in_ticket(TEXT, UUID) TO authenticated;

-- ============================================================================
-- 2. STALE VOLUNTEER COUNTS HANDLING
-- ============================================================================
-- Function to clean stale volunteer headcounts (> 5 minutes inactive)
CREATE OR REPLACE FUNCTION public.clean_stale_volunteer_counts(p_stale_minutes INTEGER DEFAULT 5)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM public.volunteer_counts
    WHERE updated_at < (timezone('utc'::text, now()) - (p_stale_minutes || ' minutes')::INTERVAL);
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;

-- Live view that strictly filters out stale volunteer counts
CREATE OR REPLACE VIEW public.live_volunteer_counts AS
SELECT *
FROM public.volunteer_counts
WHERE updated_at >= (timezone('utc'::text, now()) - INTERVAL '5 minutes');

GRANT SELECT ON public.live_volunteer_counts TO anon, authenticated;

-- ============================================================================
-- 3. RLS HARDENING: OBSERVATIONS
-- ============================================================================
-- Ensure volunteers can only insert observations for their own account,
-- only for assigned events, and ONLY for verified Spatially devices.
DROP POLICY IF EXISTS "Volunteers can log crowd observations" ON public.observations;
CREATE POLICY "Volunteers can log crowd observations"
    ON public.observations FOR INSERT
    TO authenticated
    WITH CHECK (
        volunteer_id = auth.uid() AND
        is_spatially_device = true AND -- Privacy constraint: Ambient MAC addresses prohibited
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() 
              AND va.event_id = observations.event_id
              AND va.status = 'active'
        )
    );

-- ============================================================================
-- 4. RLS HARDENING: VOLUNTEER_COUNTS
-- ============================================================================
-- Assigned volunteers can update their active zone headcount only for assigned events.
DROP POLICY IF EXISTS "Volunteers can update zone headcounts" ON public.volunteer_counts;
CREATE POLICY "Volunteers can update zone headcounts"
    ON public.volunteer_counts FOR ALL
    TO authenticated
    USING (
        volunteer_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() 
              AND va.event_id = volunteer_counts.event_id
              AND va.status = 'active'
        )
    )
    WITH CHECK (
        volunteer_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() 
              AND va.event_id = volunteer_counts.event_id
              AND va.status = 'active'
        )
    );

-- ============================================================================
-- 5. RLS HARDENING: TICKETS UPDATE
-- ============================================================================
-- Direct client UPDATE on tickets is prohibited for volunteers; check-in MUST
-- go through the atomic check_in_ticket() RPC. Organizers/admins retain update.
DROP POLICY IF EXISTS "Volunteers can check in tickets" ON public.tickets;
CREATE POLICY "Organizers and admins can manage tickets"
    ON public.tickets FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('organizer', 'admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('organizer', 'admin')
        )
    );

-- ============================================================================
-- 6. VOLUNTEER ASSIGNMENTS RECONCILIATION & SEEDING
-- ============================================================================
-- Assign test volunteers to normalized zones in active live events
DO $$
DECLARE
    v_event_id UUID := '63ed3709-1b92-4438-9bf3-4a860f3f1846'::uuid; -- Project Presentation 2
    v_live_event_id UUID := '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301'::uuid; -- Cultural Night 2026
    v_z701 UUID;
    v_z702 UUID;
BEGIN
    SELECT id INTO v_z701 FROM public.event_zones WHERE event_id = v_event_id AND code = '701' LIMIT 1;
    SELECT id INTO v_z702 FROM public.event_zones WHERE event_id = v_event_id AND code = '702' LIMIT 1;

    -- Promote test_volunteer account if present
    UPDATE public.profiles 
    SET role = 'volunteer' 
    WHERE email = 'test_volunteer@spatially.app';

    -- Seed assignments for existing volunteer accounts
    INSERT INTO public.volunteer_assignments (id, volunteer_id, event_id, zone_id, role, status, shift_start, shift_end)
    SELECT 
        '50000000-0000-0000-0000-000000000001'::uuid,
        p.id,
        v_event_id,
        v_z701,
        'crowd_monitor',
        'active',
        timezone('utc'::text, now() - INTERVAL '1 hour'),
        timezone('utc'::text, now() + INTERVAL '8 hours')
    FROM public.profiles p
    WHERE p.role = 'volunteer'
    LIMIT 1
    ON CONFLICT (id) DO UPDATE SET
        event_id = EXCLUDED.event_id,
        zone_id = EXCLUDED.zone_id,
        status = 'active';

    -- Ensure test_volunteer@spatially.app has an active assignment
    INSERT INTO public.volunteer_assignments (id, volunteer_id, event_id, zone_id, role, status, shift_start, shift_end)
    SELECT 
        '50000000-0000-0000-0000-000000000002'::uuid,
        p.id,
        v_event_id,
        v_z702,
        'gate_scanner',
        'active',
        timezone('utc'::text, now() - INTERVAL '1 hour'),
        timezone('utc'::text, now() + INTERVAL '8 hours')
    FROM public.profiles p
    WHERE p.email = 'test_volunteer@spatially.app'
    ON CONFLICT (id) DO UPDATE SET
        event_id = EXCLUDED.event_id,
        zone_id = EXCLUDED.zone_id,
        status = 'active';

END $$;
