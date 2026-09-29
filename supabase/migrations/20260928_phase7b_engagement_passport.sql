-- ==============================================================================
-- Migration: 20260928_phase7b_engagement_passport.sql
-- Description: Phase 7B Attendee Engagements Ledger, RLS, and Server-Authoritative RPCs
-- ==============================================================================

-- 1. Create public.attendee_engagements ledger
CREATE TABLE IF NOT EXISTS public.attendee_engagements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    attendee_id UUID NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    engagement_type TEXT NOT NULL CHECK (engagement_type IN ('check_in', 'activity', 'booth', 'session')),
    reference_id UUID NULL,
    points_earned INTEGER NOT NULL DEFAULT 0 CHECK (points_earned >= 0),
    verified_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    verification_method TEXT NOT NULL CHECK (verification_method IN ('qr_code', 'checkpoint_code', 'beacon', 'volunteer', 'system')),
    metadata JSONB NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    
    -- Idempotency constraint: exactly one engagement per target per attendee
    CONSTRAINT uq_attendee_engagement UNIQUE (event_id, attendee_id, engagement_type, reference_id)
);

-- Indexes for performance on passport queries
CREATE INDEX IF NOT EXISTS idx_attendee_engagements_event_attendee 
ON public.attendee_engagements(event_id, attendee_id, engagement_type);

CREATE INDEX IF NOT EXISTS idx_attendee_engagements_user 
ON public.attendee_engagements(user_id);

-- 2. Row Level Security Lockdown
ALTER TABLE public.attendee_engagements ENABLE ROW LEVEL SECURITY;

-- Policy 1: Authenticated attendees can view their own engagements
DROP POLICY IF EXISTS "Authenticated users can read own engagements" ON public.attendee_engagements;
CREATE POLICY "Authenticated users can read own engagements"
ON public.attendee_engagements
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy 2: Organizers / Admins can view event engagements
DROP POLICY IF EXISTS "Organizers can view event engagements" ON public.attendee_engagements;
CREATE POLICY "Organizers can view event engagements"
ON public.attendee_engagements
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
        AND p.role IN ('organizer', 'admin')
    )
);

-- Note: Guest attendees read their progress exclusively via get_attendee_passport_summary RPC,
-- preventing any global table exposure or leakage of other attendees' records.

-- 3. RPC: verify_activity_completion
CREATE OR REPLACE FUNCTION public.verify_activity_completion(
    p_event_id UUID,
    p_attendee_id UUID,
    p_activity_id UUID,
    p_verification_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_ticket RECORD;
    v_activity RECORD;
    v_existing RECORD;
    v_total_points INT;
    v_code_clean TEXT;
BEGIN
    v_caller_id := auth.uid();
    
    -- 1. Validate required inputs
    IF p_event_id IS NULL OR p_attendee_id IS NULL OR p_activity_id IS NULL THEN
        RAISE EXCEPTION 'Missing required parameters' USING ERRCODE = '22023';
    END IF;

    -- 2. Verify ticket ownership and physical admission (must be checked_in)
    SELECT * INTO v_ticket
    FROM public.tickets
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND (
          (v_caller_id IS NOT NULL AND (user_id = v_caller_id OR user_id IS NULL))
          OR (v_caller_id IS NULL AND user_id IS NULL)
      )
    LIMIT 1;

    IF v_ticket IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'NO_VALID_TICKET',
            'message', 'No valid ticket found for this attendee and event'
        );
    END IF;

    IF v_ticket.status <> 'checked_in' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'NOT_CHECKED_IN',
            'message', 'Attendee must be checked in at the venue before completing activities'
        );
    END IF;

    -- 3. Verify event is active or upcoming
    IF NOT EXISTS (
        SELECT 1 FROM public.events
        WHERE id = p_event_id AND status IN ('live', 'upcoming')
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'EVENT_INACTIVE',
            'message', 'Event is not currently active'
        );
    END IF;

    -- 4. Verify activity exists, is active, and scoped to this event
    SELECT * INTO v_activity
    FROM public.activities
    WHERE id = p_activity_id AND event_id = p_event_id;

    IF v_activity IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACTIVITY_NOT_FOUND',
            'message', 'Activity not found for this event'
        );
    END IF;

    IF NOT v_activity.is_active THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACTIVITY_INACTIVE',
            'message', 'This activity is currently closed or inactive'
        );
    END IF;

    -- 5. Verification Code Check
    v_code_clean := UPPER(TRIM(COALESCE(p_verification_code, '')));
    IF v_code_clean = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'CODE_REQUIRED',
            'message', 'Checkpoint verification code is required'
        );
    END IF;

    -- 6. Check Idempotency (already completed?)
    SELECT * INTO v_existing
    FROM public.attendee_engagements
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND engagement_type = 'activity'
      AND reference_id = p_activity_id;

    IF FOUND THEN
        SELECT COALESCE(SUM(points_earned), 0) INTO v_total_points
        FROM public.attendee_engagements
        WHERE event_id = p_event_id AND attendee_id = p_attendee_id;

        RETURN jsonb_build_object(
            'success', true,
            'already_completed', true,
            'points_awarded', 0,
            'total_points', v_total_points,
            'activity_id', p_activity_id,
            'activity_title', v_activity.title,
            'verified_at', v_existing.verified_at,
            'message', 'Activity already completed'
        );
    END IF;

    -- 7. Record Completion in Ledger
    INSERT INTO public.attendee_engagements (
        event_id,
        attendee_id,
        user_id,
        engagement_type,
        reference_id,
        points_earned,
        verified_at,
        verification_method,
        metadata
    ) VALUES (
        p_event_id,
        p_attendee_id,
        v_ticket.user_id,
        'activity',
        p_activity_id,
        v_activity.points_reward,
        timezone('utc', now()),
        'checkpoint_code',
        jsonb_build_object(
            'title', v_activity.title,
            'activity_type', v_activity.activity_type,
            'zone_id', v_activity.zone_id,
            'poi_id', v_activity.poi_id
        )
    )
    ON CONFLICT (event_id, attendee_id, engagement_type, reference_id) DO NOTHING;

    -- 8. Return updated points & status
    SELECT COALESCE(SUM(points_earned), 0) INTO v_total_points
    FROM public.attendee_engagements
    WHERE event_id = p_event_id AND attendee_id = p_attendee_id;

    RETURN jsonb_build_object(
        'success', true,
        'already_completed', false,
        'points_awarded', v_activity.points_reward,
        'total_points', v_total_points,
        'activity_id', p_activity_id,
        'activity_title', v_activity.title,
        'verified_at', timezone('utc', now()),
        'message', 'Checkpoint verified successfully!'
    );
END;
$$;

-- 4. RPC: record_booth_visit
CREATE OR REPLACE FUNCTION public.record_booth_visit(
    p_event_id UUID,
    p_attendee_id UUID,
    p_booth_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_ticket RECORD;
    v_booth RECORD;
    v_existing RECORD;
BEGIN
    v_caller_id := auth.uid();

    IF p_event_id IS NULL OR p_attendee_id IS NULL OR p_booth_id IS NULL THEN
        RAISE EXCEPTION 'Missing required parameters' USING ERRCODE = '22023';
    END IF;

    -- Verify ticket ownership and admission
    SELECT * INTO v_ticket
    FROM public.tickets
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND (
          (v_caller_id IS NOT NULL AND (user_id = v_caller_id OR user_id IS NULL))
          OR (v_caller_id IS NULL AND user_id IS NULL)
      )
    LIMIT 1;

    IF v_ticket IS NULL OR v_ticket.status <> 'checked_in' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'NOT_CHECKED_IN',
            'message', 'Attendee must be checked into the event to record booth visits'
        );
    END IF;

    -- Verify booth exists and belongs to this event
    SELECT * INTO v_booth
    FROM public.booths
    WHERE id = p_booth_id AND event_id = p_event_id;

    IF v_booth IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'BOOTH_NOT_FOUND',
            'message', 'Booth not found for this event'
        );
    END IF;

    -- Idempotency check
    SELECT * INTO v_existing
    FROM public.attendee_engagements
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND engagement_type = 'booth'
      AND reference_id = p_booth_id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_visited', true,
            'booth_id', p_booth_id,
            'booth_name', v_booth.name,
            'verified_at', v_existing.verified_at,
            'message', 'Booth already logged as visited'
        );
    END IF;

    -- Insert booth visit (points = 0 per approved product economy)
    INSERT INTO public.attendee_engagements (
        event_id,
        attendee_id,
        user_id,
        engagement_type,
        reference_id,
        points_earned,
        verified_at,
        verification_method,
        metadata
    ) VALUES (
        p_event_id,
        p_attendee_id,
        v_ticket.user_id,
        'booth',
        p_booth_id,
        0,
        timezone('utc', now()),
        'system',
        jsonb_build_object(
            'name', v_booth.name,
            'booth_number', v_booth.booth_number,
            'category', v_booth.category,
            'zone_id', v_booth.zone_id,
            'poi_id', v_booth.poi_id
        )
    )
    ON CONFLICT (event_id, attendee_id, engagement_type, reference_id) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'already_visited', false,
        'booth_id', p_booth_id,
        'booth_name', v_booth.name,
        'verified_at', timezone('utc', now()),
        'message', 'Booth visit logged in passport!'
    );
END;
$$;

-- 5. RPC: record_session_attendance
CREATE OR REPLACE FUNCTION public.record_session_attendance(
    p_event_id UUID,
    p_attendee_id UUID,
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_ticket RECORD;
    v_session RECORD;
    v_existing RECORD;
BEGIN
    v_caller_id := auth.uid();

    IF p_event_id IS NULL OR p_attendee_id IS NULL OR p_session_id IS NULL THEN
        RAISE EXCEPTION 'Missing required parameters' USING ERRCODE = '22023';
    END IF;

    -- Verify ticket ownership and admission
    SELECT * INTO v_ticket
    FROM public.tickets
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND (
          (v_caller_id IS NOT NULL AND (user_id = v_caller_id OR user_id IS NULL))
          OR (v_caller_id IS NULL AND user_id IS NULL)
      )
    LIMIT 1;

    IF v_ticket IS NULL OR v_ticket.status <> 'checked_in' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'NOT_CHECKED_IN',
            'message', 'Attendee must be checked into the event to record session attendance'
        );
    END IF;

    -- Verify session exists and belongs to this event
    SELECT * INTO v_session
    FROM public.sessions
    WHERE id = p_session_id AND event_id = p_event_id;

    IF v_session IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'SESSION_NOT_FOUND',
            'message', 'Session not found for this event'
        );
    END IF;

    -- Idempotency check
    SELECT * INTO v_existing
    FROM public.attendee_engagements
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND engagement_type = 'session'
      AND reference_id = p_session_id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_attended', true,
            'session_id', p_session_id,
            'session_title', v_session.title,
            'verified_at', v_existing.verified_at,
            'message', 'Session attendance already recorded'
        );
    END IF;

    -- Insert session attendance (points = 0 per approved product economy)
    INSERT INTO public.attendee_engagements (
        event_id,
        attendee_id,
        user_id,
        engagement_type,
        reference_id,
        points_earned,
        verified_at,
        verification_method,
        metadata
    ) VALUES (
        p_event_id,
        p_attendee_id,
        v_ticket.user_id,
        'session',
        p_session_id,
        0,
        timezone('utc', now()),
        'system',
        jsonb_build_object(
            'title', v_session.title,
            'speaker_name', v_session.speaker_name,
            'stage_name', v_session.stage_name,
            'zone_id', v_session.zone_id,
            'poi_id', v_session.poi_id
        )
    )
    ON CONFLICT (event_id, attendee_id, engagement_type, reference_id) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'already_attended', false,
        'session_id', p_session_id,
        'session_title', v_session.title,
        'verified_at', timezone('utc', now()),
        'message', 'Session attendance recorded in passport!'
    );
END;
$$;

-- 6. RPC: get_attendee_passport_summary
CREATE OR REPLACE FUNCTION public.get_attendee_passport_summary(
    p_event_id UUID,
    p_attendee_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_ticket RECORD;
    v_is_checked_in BOOLEAN := false;
    v_checked_in_at TIMESTAMPTZ;
    v_sessions_count INT := 0;
    v_booths_count INT := 0;
    v_activities_count INT := 0;
    v_total_points INT := 0;
    v_zones_count INT := 0;
    v_badges_unlocked INT := 0;
    v_timeline JSONB := '[]'::jsonb;
    v_achievements JSONB;
    v_event RECORD;
BEGIN
    v_caller_id := auth.uid();

    -- 1. Resolve event details
    SELECT * INTO v_event FROM public.events WHERE id = p_event_id;

    -- 2. Verify ticket authorization
    SELECT * INTO v_ticket
    FROM public.tickets
    WHERE event_id = p_event_id
      AND attendee_id = p_attendee_id
      AND (
          (v_caller_id IS NOT NULL AND (user_id = v_caller_id OR user_id IS NULL))
          OR (v_caller_id IS NULL AND user_id IS NULL)
          OR EXISTS (
              SELECT 1 FROM public.profiles p 
              WHERE p.id = v_caller_id AND p.role IN ('organizer', 'admin')
          )
      )
    LIMIT 1;

    IF FOUND THEN
        v_is_checked_in := (v_ticket.status = 'checked_in');
        v_checked_in_at := v_ticket.checked_in_at;
    END IF;

    -- 3. Aggregate metrics from authoritative ledger
    SELECT 
        COUNT(*) FILTER (WHERE engagement_type = 'session'),
        COUNT(*) FILTER (WHERE engagement_type = 'booth'),
        COUNT(*) FILTER (WHERE engagement_type = 'activity'),
        COALESCE(SUM(points_earned), 0)
    INTO
        v_sessions_count,
        v_booths_count,
        v_activities_count,
        v_total_points
    FROM public.attendee_engagements
    WHERE event_id = p_event_id AND attendee_id = p_attendee_id;

    -- 4. Calculate distinct zones visited
    SELECT COUNT(DISTINCT zone_val) INTO v_zones_count
    FROM (
        SELECT metadata->>'zone_id' AS zone_val
        FROM public.attendee_engagements
        WHERE event_id = p_event_id
          AND attendee_id = p_attendee_id
          AND metadata->>'zone_id' IS NOT NULL
        UNION
        SELECT 'main_checkin_zone' WHERE v_is_checked_in
    ) sub;

    -- 5. Build timeline entries
    SELECT COALESCE(jsonb_agg(entry_data ORDER BY entry_data->>'timestamp' DESC), '[]'::jsonb)
    INTO v_timeline
    FROM (
        -- Check-in entry
        SELECT jsonb_build_object(
            'id', 'checkin_' || p_event_id || '_' || p_attendee_id,
            'eventId', p_event_id,
            'timestamp', v_checked_in_at,
            'title', 'Event Check-in Confirmed',
            'subtitle', 'Verified contactless admission at venue entrance',
            'type', 'checkIn',
            'locationName', COALESCE(v_event.venue, 'Main Registration Hub'),
            'isVerified', true,
            'points', 0
        ) AS entry_data
        WHERE v_is_checked_in AND v_checked_in_at IS NOT NULL

        UNION ALL

        -- Engagements entries
        SELECT jsonb_build_object(
            'id', ae.id,
            'eventId', ae.event_id,
            'timestamp', ae.verified_at,
            'referenceId', ae.reference_id,
            'title', CASE 
                WHEN ae.engagement_type = 'activity' THEN COALESCE(ae.metadata->>'title', 'Interactive Challenge')
                WHEN ae.engagement_type = 'booth' THEN 'Visited ' || COALESCE(ae.metadata->>'name', 'Project Booth')
                WHEN ae.engagement_type = 'session' THEN 'Attended ' || COALESCE(ae.metadata->>'title', 'Event Session')
                ELSE 'Event Milestone'
            END,
            'subtitle', CASE
                WHEN ae.engagement_type = 'activity' THEN '+' || ae.points_earned || ' PTS • Verified Challenge'
                WHEN ae.engagement_type = 'booth' THEN 'Showcase ' || COALESCE(ae.metadata->>'booth_number', '') || ' • ' || COALESCE(ae.metadata->>'category', 'Exhibitor')
                WHEN ae.engagement_type = 'session' THEN 'Speaker: ' || COALESCE(ae.metadata->>'speaker_name', 'Featured Presenter')
                ELSE 'Verified Milestone'
            END,
            'type', CASE 
                WHEN ae.engagement_type = 'activity' THEN 'activity'
                WHEN ae.engagement_type = 'booth' THEN 'booth'
                WHEN ae.engagement_type = 'session' THEN 'session'
                ELSE 'milestone'
            END,
            'locationName', COALESCE(ae.metadata->>'stage_name', ae.metadata->>'room_name', v_event.venue, 'Venue Zone'),
            'isVerified', true,
            'points', ae.points_earned
        ) AS entry_data
        FROM public.attendee_engagements ae
        WHERE ae.event_id = p_event_id AND ae.attendee_id = p_attendee_id
    ) entries;

    -- 6. Evaluate achievements against authoritative thresholds
    v_badges_unlocked := 
        (CASE WHEN v_is_checked_in THEN 1 ELSE 0 END) +
        (CASE WHEN v_sessions_count >= 1 THEN 1 ELSE 0 END) +
        (CASE WHEN v_zones_count >= 3 THEN 1 ELSE 0 END) +
        (CASE WHEN v_booths_count >= 4 THEN 1 ELSE 0 END) +
        (CASE WHEN v_activities_count >= 1 THEN 1 ELSE 0 END) +
        (CASE WHEN v_total_points >= 100 THEN 1 ELSE 0 END);

    v_achievements := jsonb_build_array(
        jsonb_build_object(
            'id', 'badge_pioneer',
            'title', 'Event Pioneer',
            'description', 'Check in to the venue with your contactless admission ticket',
            'category', 'checkIn',
            'requiredCount', 1,
            'currentCount', CASE WHEN v_is_checked_in THEN 1 ELSE 0 END,
            'isUnlocked', v_is_checked_in,
            'unlockedAt', v_checked_in_at
        ),
        jsonb_build_object(
            'id', 'badge_keynote',
            'title', 'Keynote Listener',
            'description', 'Attend a live keynote or plenary session',
            'category', 'session',
            'requiredCount', 1,
            'currentCount', v_sessions_count,
            'isUnlocked', (v_sessions_count >= 1)
        ),
        jsonb_build_object(
            'id', 'badge_explorer',
            'title', 'Spatial Explorer',
            'description', 'Explore 3 or more distinct venue zones and rooms',
            'category', 'exploration',
            'requiredCount', 3,
            'currentCount', v_zones_count,
            'isUnlocked', (v_zones_count >= 3)
        ),
        jsonb_build_object(
            'id', 'badge_booths',
            'title', 'Booth Hunter',
            'description', 'Visit 4 project or exhibitor showcases on the floor',
            'category', 'booth',
            'requiredCount', 4,
            'currentCount', v_booths_count,
            'isUnlocked', (v_booths_count >= 4)
        ),
        jsonb_build_object(
            'id', 'badge_quest_master',
            'title', 'Quest Master',
            'description', 'Complete an interactive on-site engagement challenge',
            'category', 'activity',
            'requiredCount', 1,
            'currentCount', v_activities_count,
            'isUnlocked', (v_activities_count >= 1)
        ),
        jsonb_build_object(
            'id', 'badge_finisher',
            'title', 'Event Finisher',
            'description', 'Earn 100+ points across all event experiences',
            'category', 'activity',
            'requiredCount', 100,
            'currentCount', v_total_points,
            'isUnlocked', (v_total_points >= 100)
        )
    );

    -- 7. Return complete structured response
    RETURN jsonb_build_object(
        'success', true,
        'eventId', p_event_id,
        'attendeeId', p_attendee_id,
        'isCheckedIn', v_is_checked_in,
        'checkedInAt', v_checked_in_at,
        'progress', jsonb_build_object(
            'eventId', p_event_id,
            'sessionsAttended', v_sessions_count,
            'boothsVisited', v_booths_count,
            'activitiesCompleted', v_activities_count,
            'zonesVisited', v_zones_count,
            'pointsEarned', v_total_points,
            'badgesUnlocked', v_badges_unlocked
        ),
        'timeline', v_timeline,
        'achievements', v_achievements
    );
END;
$$;

-- 7. Update claim_guest_tickets to associate attendee_engagements atomically upon claim
CREATE OR REPLACE FUNCTION public.claim_guest_tickets(
    p_device_id TEXT,
    p_claim_token TEXT DEFAULT NULL
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
    v_calling_user_id := auth.uid();
    IF v_calling_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to claim guest tickets' USING ERRCODE = '28000';
    END IF;

    IF p_device_id IS NULL OR trim(p_device_id) = '' THEN
        RAISE EXCEPTION 'device_id parameter is required' USING ERRCODE = '22023';
    END IF;

    SELECT COUNT(*) INTO v_already_owned_count
    FROM public.tickets
    WHERE attendee_id = p_device_id::uuid AND user_id = v_calling_user_id;

    SELECT COUNT(*) INTO v_conflict_count
    FROM public.tickets
    WHERE attendee_id = p_device_id::uuid AND user_id IS NOT NULL AND user_id != v_calling_user_id;

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

    -- Also link all existing guest engagements to this claimed user account
    UPDATE public.attendee_engagements
    SET user_id = v_calling_user_id
    WHERE attendee_id = p_device_id::uuid AND user_id IS NULL;

    RETURN jsonb_build_object(
        'success', true,
        'claimed_count', v_claimed_count,
        'already_owned_count', v_already_owned_count,
        'conflict_count', v_conflict_count,
        'claimed_ticket_ids', v_claimed_ids
    );
END;
$$;
