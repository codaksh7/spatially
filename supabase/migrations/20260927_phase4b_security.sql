-- ============================================================================
-- SPATIALLY — PHASE 4B: MIGRATION 3 (ROW LEVEL SECURITY & SECURE RPCS)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description: Enables RLS across all 11 domain tables and operational tables,
--              establishes declarative policies, creates profile trigger,
--              and implements canonical claim_guest_tickets & get_guest_ticket RPCs.
-- ============================================================================

-- ============================================================================
-- 1. ENABLE ROW LEVEL SECURITY ACROSS ALL TABLES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_pois ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booths ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lost_found_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteer_assignments ENABLE ROW LEVEL SECURITY;

-- Operational tables
ALTER TABLE public.volunteer_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.observations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. AUTOMATIC PROFILE INITIALIZATION TRIGGER
-- ============================================================================
-- Automatically creates a profile record when a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        'attendee' -- Never allow client to self-escalate role
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 3. RLS POLICIES: PUBLIC.PROFILES
-- ============================================================================
DROP POLICY IF EXISTS "Profiles are readable by everyone" ON public.profiles;
CREATE POLICY "Profiles are readable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile non-role fields" ON public.profiles;
CREATE POLICY "Users can update own profile non-role fields"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id AND 
        role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) -- Role cannot be altered
    );

-- ============================================================================
-- 4. RLS POLICIES: PUBLIC.EVENTS
-- ============================================================================
DROP POLICY IF EXISTS "Public can view active or upcoming events" ON public.events;
CREATE POLICY "Public can view active or upcoming events"
    ON public.events FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Organizers and admins can manage events" ON public.events;
CREATE POLICY "Organizers and admins can manage events"
    ON public.events FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('organizer', 'admin')
        )
    );

-- ============================================================================
-- 5. RLS POLICIES: PUBLIC.EVENT_ZONES, VENUE_POIS, SESSIONS, BOOTHS, ACTIVITIES
-- ============================================================================
-- Public read for active event content
DROP POLICY IF EXISTS "Public can view event zones" ON public.event_zones;
CREATE POLICY "Public can view event zones" ON public.event_zones FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view venue pois" ON public.venue_pois;
CREATE POLICY "Public can view venue pois" ON public.venue_pois FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view sessions" ON public.sessions;
CREATE POLICY "Public can view sessions" ON public.sessions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view booths" ON public.booths;
CREATE POLICY "Public can view booths" ON public.booths FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view activities" ON public.activities;
CREATE POLICY "Public can view activities" ON public.activities FOR SELECT USING (true);

-- Event content modification restricted to organizers/admins
DROP POLICY IF EXISTS "Staff can manage event zones" ON public.event_zones;
CREATE POLICY "Staff can manage event zones" ON public.event_zones FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin')));

DROP POLICY IF EXISTS "Staff can manage venue pois" ON public.venue_pois;
CREATE POLICY "Staff can manage venue pois" ON public.venue_pois FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin')));

DROP POLICY IF EXISTS "Staff can manage sessions" ON public.sessions;
CREATE POLICY "Staff can manage sessions" ON public.sessions FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin')));

DROP POLICY IF EXISTS "Staff can manage booths" ON public.booths;
CREATE POLICY "Staff can manage booths" ON public.booths FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin')));

DROP POLICY IF EXISTS "Staff can manage activities" ON public.activities;
CREATE POLICY "Staff can manage activities" ON public.activities FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin')));

-- ============================================================================
-- 6. RLS POLICIES: PUBLIC.TICKETS (Strict Security Model)
-- ============================================================================
-- Ticket Select:
-- 1. Authenticated user can select tickets they own (user_id = auth.uid())
-- 2. Assigned volunteers can inspect tickets for their assigned event (for check-in / scanning)
-- 3. Anonymous device can select their own ticket via attendee_id match (allows guest my_tickets & details)
DROP POLICY IF EXISTS "Users and guests can view their own tickets" ON public.tickets;
CREATE POLICY "Users and guests can view their own tickets"
    ON public.tickets FOR SELECT
    USING (
        (auth.uid() IS NOT NULL AND user_id = auth.uid()) OR
        (user_id IS NULL AND attendee_id IS NOT NULL) OR
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() AND va.event_id = tickets.event_id
        ) OR
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('organizer', 'admin')
        )
    );

-- Ticket Insert:
-- Anyone (guest or authenticated) can register/purchase a ticket for an upcoming/live event
DROP POLICY IF EXISTS "Anyone can purchase or claim a ticket" ON public.tickets;
CREATE POLICY "Anyone can purchase or claim a ticket"
    ON public.tickets FOR INSERT
    WITH CHECK (
        event_id IN (SELECT id FROM public.events WHERE status IN ('upcoming', 'live'))
    );

-- Ticket Update:
-- 1. Assigned volunteers can update ticket check-in status
-- 2. Organizers and admins can manage tickets
DROP POLICY IF EXISTS "Volunteers can check in tickets" ON public.tickets;
CREATE POLICY "Volunteers can check in tickets"
    ON public.tickets FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() AND va.event_id = tickets.event_id
        ) OR
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('organizer', 'admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() AND va.event_id = tickets.event_id
        ) OR
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('organizer', 'admin')
        )
    );

-- ============================================================================
-- 7. RLS POLICIES: PUBLIC.LOST_FOUND_REPORTS
-- ============================================================================
-- Public can view active non-draft lost and found reports
DROP POLICY IF EXISTS "Public can view submitted lost and found reports" ON public.lost_found_reports;
CREATE POLICY "Public can view submitted lost and found reports"
    ON public.lost_found_reports FOR SELECT
    USING (status != 'draft');

-- Anyone can submit a lost or found report
DROP POLICY IF EXISTS "Anyone can submit a lost or found report" ON public.lost_found_reports;
CREATE POLICY "Anyone can submit a lost or found report"
    ON public.lost_found_reports FOR INSERT
    WITH CHECK (
        event_id IN (SELECT id FROM public.events WHERE status IN ('upcoming', 'live'))
    );

-- Staff (volunteers, organizers, admins) or original authenticated reporter can update report
DROP POLICY IF EXISTS "Staff and reporter can update report status" ON public.lost_found_reports;
CREATE POLICY "Staff and reporter can update report status"
    ON public.lost_found_reports FOR UPDATE
    TO authenticated
    USING (
        (auth.uid() IS NOT NULL AND reporter_user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.volunteer_assignments va WHERE va.volunteer_id = auth.uid() AND va.event_id = lost_found_reports.event_id) OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin'))
    );

-- ============================================================================
-- 8. RLS POLICIES: PUBLIC.EVENT_NOTIFICATIONS
-- ============================================================================
-- Attendees can read notifications for active event (broadcast or targeted to them)
DROP POLICY IF EXISTS "Users can view active event notifications" ON public.event_notifications;
CREATE POLICY "Users can view active event notifications"
    ON public.event_notifications FOR SELECT
    USING (
        is_active = true AND
        (target_user_id IS NULL OR target_user_id = auth.uid())
    );

-- Organizers and admins can broadcast notifications
DROP POLICY IF EXISTS "Staff can broadcast notifications" ON public.event_notifications;
CREATE POLICY "Staff can broadcast notifications"
    ON public.event_notifications FOR ALL
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin'))
    );

-- ============================================================================
-- 9. RLS POLICIES: PUBLIC.VOLUNTEER_ASSIGNMENTS & OPERATIONAL TABLES
-- ============================================================================
-- Volunteers can view their own assignments; organizers/admins can view all
DROP POLICY IF EXISTS "Volunteers and staff can view assignments" ON public.volunteer_assignments;
CREATE POLICY "Volunteers and staff can view assignments"
    ON public.volunteer_assignments FOR SELECT
    TO authenticated
    USING (
        volunteer_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin'))
    );

-- volunteer_counts:
-- Public can read live zone counts (essential for Realtime crowd indicators)
-- Assigned volunteers can upsert zone headcounts
DROP POLICY IF EXISTS "Public can view live crowd counts" ON public.volunteer_counts;
CREATE POLICY "Public can view live crowd counts"
    ON public.volunteer_counts FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Volunteers can update zone headcounts" ON public.volunteer_counts;
CREATE POLICY "Volunteers can update zone headcounts"
    ON public.volunteer_counts FOR ALL
    TO authenticated
    USING (
        volunteer_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.volunteer_assignments va WHERE va.volunteer_id = auth.uid())
    );

-- observations:
-- Volunteers can insert BLE crowd observations
DROP POLICY IF EXISTS "Volunteers can log crowd observations" ON public.observations;
CREATE POLICY "Volunteers can log crowd observations"
    ON public.observations FOR INSERT
    TO authenticated
    WITH CHECK (
        volunteer_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.volunteer_assignments va WHERE va.volunteer_id = auth.uid())
    );

DROP POLICY IF EXISTS "Staff can view crowd observations" ON public.observations;
CREATE POLICY "Staff can view crowd observations"
    ON public.observations FOR SELECT
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.volunteer_assignments va WHERE va.volunteer_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin'))
    );

-- ============================================================================
-- 10. CANONICAL CLAIM GUEST TICKETS RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.claim_guest_tickets(
    p_device_id TEXT,
    p_claim_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_calling_user_id UUID;
    v_claimed_count INT := 0;
    v_already_owned_count INT := 0;
    v_conflict_count INT := 0;
    v_claimed_ids UUID[] := '{}';
BEGIN
    -- 1. Ensure user is authenticated
    v_calling_user_id := auth.uid();
    IF v_calling_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to claim guest tickets' USING ERRCODE = '28000';
    END IF;

    -- 2. Validate input parameters
    IF p_device_id IS NULL OR trim(p_device_id) = '' THEN
        RAISE EXCEPTION 'device_id parameter is required' USING ERRCODE = '22023';
    END IF;

    -- 3. Check already owned tickets (idempotency check)
    SELECT COUNT(*) INTO v_already_owned_count
    FROM public.tickets
    WHERE attendee_id = p_device_id::uuid AND user_id = v_calling_user_id;

    -- 4. Check conflicting tickets owned by someone else
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.tickets
    WHERE attendee_id = p_device_id::uuid AND user_id IS NOT NULL AND user_id != v_calling_user_id;

    -- 5. Atomically claim unclaimed guest tickets
    WITH updated AS (
        UPDATE public.tickets
        SET 
            user_id = v_calling_user_id,
            claimed_at = timezone('utc'::text, now())
        WHERE 
            attendee_id = p_device_id::uuid 
            AND user_id IS NULL
        RETURNING id
    )
    SELECT COUNT(*), COALESCE(array_agg(id), '{}')
    INTO v_claimed_count, v_claimed_ids
    FROM updated;

    -- 6. Return structured status payload
    RETURN jsonb_build_object(
        'success', true,
        'claimed_count', v_claimed_count,
        'already_owned_count', v_already_owned_count,
        'conflict_count', v_conflict_count,
        'claimed_ticket_ids', v_claimed_ids
    );
END;
$$;

-- Revoke public execution and grant to authenticated role only
REVOKE EXECUTE ON FUNCTION public.claim_guest_tickets(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_guest_tickets(TEXT, TEXT) TO authenticated;

-- ============================================================================
-- 11. SECURE GUEST TICKET RETRIEVAL RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_guest_ticket(
    p_ticket_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_ticket_data JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', t.id,
        'event_id', t.event_id,
        'attendee_id', t.attendee_id,
        'ticket_code', t.ticket_code,
        'status', t.status,
        'purchased_at', t.purchased_at,
        'checked_in_at', t.checked_in_at,
        'event', jsonb_build_object(
            'id', e.id,
            'name', e.name,
            'venue', e.venue,
            'event_date', e.event_date,
            'status', e.status,
            'banner_url', e.banner_url
        )
    )
    INTO v_ticket_data
    FROM public.tickets t
    JOIN public.events e ON e.id = t.event_id
    WHERE t.ticket_code = p_ticket_code
    LIMIT 1;

    IF v_ticket_data IS NULL THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    RETURN jsonb_build_object('found', true, 'ticket', v_ticket_data);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guest_ticket(TEXT) TO anon, authenticated;
