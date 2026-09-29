-- ============================================================================
-- SPATIALLY — VOLUNTEER BLOCK 1: PRODUCTION INTEGRITY, SECURITY & DATA PASS
-- Migration: 20260929_volunteer_block1_integrity.sql
-- ============================================================================

-- 1. ATOMIC TICKET CHECK-IN RPC WITH VOLUNTEER ATTRIBUTION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_in_ticket(
    p_ticket_code TEXT,
    p_event_id UUID,
    p_volunteer_id UUID DEFAULT NULL
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
    -- 1. Determine caller / volunteer identity
    v_caller_id := COALESCE(p_volunteer_id, auth.uid());
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'UNAUTHORIZED',
            'message', 'Authentication required to check in tickets.'
        );
    END IF;

    -- 2. Verify volunteer/staff role in profiles
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('volunteer', 'organizer', 'admin') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'FORBIDDEN',
            'message', 'Only authorized volunteers or event staff can check in tickets.'
        );
    END IF;

    -- 3. Verify volunteer is actively assigned to this specific event (if role is volunteer)
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

REVOKE ALL ON FUNCTION public.check_in_ticket(TEXT, UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_in_ticket(TEXT, UUID, UUID) TO authenticated;

-- ============================================================================
-- 2. HARDEN OBSERVATIONS RLS
-- ============================================================================
DROP POLICY IF EXISTS "Volunteers can log crowd observations" ON public.observations;

CREATE POLICY "Volunteers can log crowd observations"
ON public.observations
FOR INSERT
TO authenticated
WITH CHECK (
    volunteer_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.volunteer_assignments va
        JOIN public.event_zones ez ON ez.event_id = va.event_id
        WHERE va.volunteer_id = auth.uid()
          AND va.event_id = observations.event_id
          AND va.status = 'active'
          AND (
            (va.zone_id IS NOT NULL AND va.zone_id = ez.id AND (ez.code = observations.zone OR ez.name = observations.zone))
            OR
            (va.zone_id IS NULL AND (ez.code = observations.zone OR ez.name = observations.zone))
          )
    )
);

-- ============================================================================
-- 3. HARDEN VOLUNTEER_COUNTS RLS (PRESERVES PUBLIC SELECT)
-- ============================================================================
DROP POLICY IF EXISTS "Volunteers can update zone headcounts" ON public.volunteer_counts;

CREATE POLICY "Volunteers can update zone headcounts"
ON public.volunteer_counts
FOR ALL
TO authenticated
USING (
    volunteer_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.volunteer_assignments va
        JOIN public.event_zones ez ON ez.event_id = va.event_id
        WHERE va.volunteer_id = auth.uid()
          AND va.event_id = volunteer_counts.event_id
          AND va.status = 'active'
          AND (
            (va.zone_id IS NOT NULL AND va.zone_id = ez.id AND (ez.code = volunteer_counts.zone OR ez.name = volunteer_counts.zone))
            OR
            (va.zone_id IS NULL AND (ez.code = volunteer_counts.zone OR ez.name = volunteer_counts.zone))
          )
    )
)
WITH CHECK (
    volunteer_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.volunteer_assignments va
        JOIN public.event_zones ez ON ez.event_id = va.event_id
        WHERE va.volunteer_id = auth.uid()
          AND va.event_id = volunteer_counts.event_id
          AND va.status = 'active'
          AND (
            (va.zone_id IS NOT NULL AND va.zone_id = ez.id AND (ez.code = volunteer_counts.zone OR ez.name = volunteer_counts.zone))
            OR
            (va.zone_id IS NULL AND (ez.code = volunteer_counts.zone OR ez.name = volunteer_counts.zone))
          )
    )
);

-- ============================================================================
-- 4. IDEMPOTENT TEST / VOLUNTEER ASSIGNMENT PROVISIONING
-- ============================================================================
INSERT INTO public.volunteer_assignments (
    id,
    volunteer_id,
    event_id,
    zone_id,
    role,
    status,
    assigned_at
)
SELECT 
    'f0000001-0000-0000-0000-000000000001'::uuid,
    'ae30ee77-e9fc-494f-84b2-9a93910b7ddc'::uuid,
    '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301'::uuid,
    '7eb69815-d54c-4c00-85e4-58de5d95d21c'::uuid,
    'crowd_monitor',
    'active',
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.volunteer_assignments 
    WHERE volunteer_id = 'ae30ee77-e9fc-494f-84b2-9a93910b7ddc'::uuid 
      AND event_id = '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301'::uuid
);

INSERT INTO public.volunteer_assignments (
    id,
    volunteer_id,
    event_id,
    zone_id,
    role,
    status,
    assigned_at
)
SELECT 
    'f0000001-0000-0000-0000-000000000002'::uuid,
    '73015e90-8dbd-4422-88f0-d3fd48a29a8a'::uuid,
    '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301'::uuid,
    NULL,
    'crowd_monitor',
    'active',
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.volunteer_assignments 
    WHERE volunteer_id = '73015e90-8dbd-4422-88f0-d3fd48a29a8a'::uuid 
      AND event_id = '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301'::uuid
);
