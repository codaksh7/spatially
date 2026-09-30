-- ============================================================================
-- SPATIALLY — PHASE 6B: MIGRATION 3 (CONNECT SECURE RPCS & FUNCTIONS)
-- Author: Senior Software Architect & Supabase Backend Engineer
-- Date: September 28, 2026
-- Target: Spatially Attendee Mobile + Supabase Backend (bajrtiiqwqvblnbtuhvw)
-- Description: Canonical database functions for discovery, connection lifecycle,
--              rate-limited request creation, acceptance, and chat messaging.
-- ============================================================================

-- 1. GET DISCOVERABLE ATTENDEES FOR AN EVENT
CREATE OR REPLACE FUNCTION public.get_discoverable_attendees(
    p_event_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_has_ticket BOOLEAN;
    v_caller_visibility TEXT;
    v_caller_interests TEXT[];
    v_results JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Verify caller holds a valid ticket for this event
    SELECT EXISTS (
        SELECT 1 FROM public.tickets t
        WHERE t.event_id = p_event_id
        AND t.user_id = v_caller_id
        AND t.status IN ('purchased', 'checked_in')
    ) INTO v_has_ticket;

    IF NOT v_has_ticket THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Get caller's profile preferences and interests
    SELECT 
        COALESCE(p.networking_visibility, 'matchingInterests'),
        COALESCE(p.interests, '{}'::text[])
    INTO v_caller_visibility, v_caller_interests
    FROM public.profiles p
    WHERE p.id = v_caller_id;

    -- If caller is invisible, return empty list (cannot discover others)
    IF v_caller_visibility = 'invisible' THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Query eligible attendees
    SELECT COALESCE(jsonb_agg(sub.profile_data), '[]'::jsonb)
    INTO v_results
    FROM (
        SELECT 
            jsonb_build_object(
                'id', p.id,
                'displayName', COALESCE(NULLIF(p.full_name, ''), 'Attendee'),
                'headline', COALESCE(p.headline, ''),
                'bio', COALESCE(p.bio, ''),
                'interests', COALESCE(p.interests, '{}'::text[]),
                'avatarUrl', p.avatar_url,
                'avatarInitials', CASE 
                    WHEN trim(COALESCE(p.full_name, '')) = '' THEN 'A'
                    WHEN array_length(regexp_split_to_array(trim(p.full_name), '\s+'), 1) >= 2 THEN 
                        upper(substring((regexp_split_to_array(trim(p.full_name), '\s+'))[1] from 1 for 1) || 
                              substring((regexp_split_to_array(trim(p.full_name), '\s+'))[2] from 1 for 1))
                    ELSE upper(substring(trim(p.full_name) from 1 for 1))
                END,
                'locationNote', COALESCE(p.location_note, ''),
                'isReadyToChat', COALESCE(p.networking_opt_in, false),
                'sharedInterests', COALESCE(
                    ARRAY(
                        SELECT unnest(p.interests) 
                        INTERSECT 
                        SELECT unnest(v_caller_interests)
                    ), '{}'::text[]
                ),
                'connectionStatus', CASE 
                    WHEN ac.id IS NULL THEN 'none'
                    WHEN ac.status = 'pending' AND ac.requester_id = v_caller_id THEN 'requestSent'
                    WHEN ac.status = 'pending' AND ac.addressee_id = v_caller_id THEN 'requestReceived'
                    WHEN ac.status = 'accepted' THEN 'connected'
                    WHEN ac.status = 'declined' THEN 'declined'
                    ELSE 'none'
                END,
                'connectionId', ac.id
            ) AS profile_data
        FROM public.profiles p
        JOIN public.tickets t ON t.user_id = p.id AND t.event_id = p_event_id AND t.status IN ('purchased', 'checked_in')
        LEFT JOIN public.attendee_connections ac ON ac.event_id = p_event_id 
            AND ((ac.requester_id = v_caller_id AND ac.addressee_id = p.id) 
                 OR (ac.addressee_id = v_caller_id AND ac.requester_id = p.id))
        WHERE p.id <> v_caller_id
        AND p.networking_opt_in = true
        AND p.networking_visibility <> 'invisible'
        AND (
            p.networking_visibility = 'discoverable'
            OR (
                (p.networking_visibility = 'matchingInterests' OR v_caller_visibility = 'matchingInterests')
                AND ARRAY(
                    SELECT unnest(p.interests) 
                    INTERSECT 
                    SELECT unnest(v_caller_interests)
                ) <> '{}'::text[]
            )
        )
        ORDER BY p.full_name ASC
        LIMIT p_limit
        OFFSET p_offset
    ) sub;

    RETURN v_results;
END;
$$;

-- 2. SEND CONNECTION REQUEST (WITH RATE LIMITING)
CREATE OR REPLACE FUNCTION public.send_connection_request(
    p_event_id UUID,
    p_peer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_name TEXT;
    v_peer_name TEXT;
    v_recent_count INT;
    v_existing_conn RECORD;
    v_new_conn RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF v_caller_id = p_peer_id THEN
        RAISE EXCEPTION 'Cannot send connection request to yourself' USING ERRCODE = 'P0001';
    END IF;

    -- Verify event is valid and not expired past 24h
    IF NOT EXISTS (
        SELECT 1 FROM public.events e 
        WHERE e.id = p_event_id 
        AND (e.event_end_time IS NULL OR e.event_end_time >= now() - INTERVAL '24 hours')
    ) THEN
        RAISE EXCEPTION 'Event does not exist or has already concluded' USING ERRCODE = 'P0001';
    END IF;

    -- Verify caller ticket
    IF NOT EXISTS (
        SELECT 1 FROM public.tickets t 
        WHERE t.event_id = p_event_id AND t.user_id = v_caller_id AND t.status IN ('purchased', 'checked_in')
    ) THEN
        RAISE EXCEPTION 'Caller does not hold an active ticket for this event' USING ERRCODE = '42501';
    END IF;

    -- Verify peer ticket and networking opt-in
    IF NOT EXISTS (
        SELECT 1 FROM public.tickets t 
        JOIN public.profiles p ON p.id = t.user_id
        WHERE t.event_id = p_event_id 
        AND t.user_id = p_peer_id 
        AND t.status IN ('purchased', 'checked_in')
        AND p.networking_opt_in = true
        AND p.networking_visibility <> 'invisible'
    ) THEN
        RAISE EXCEPTION 'Peer attendee is not eligible for networking at this event' USING ERRCODE = 'P0001';
    END IF;

    -- Rate limit check: maximum 15 requests per hour per attendee
    SELECT count(*) INTO v_recent_count
    FROM public.attendee_connections
    WHERE requester_id = v_caller_id
    AND created_at >= (now() - INTERVAL '1 hour');

    IF v_recent_count >= 15 THEN
        RAISE EXCEPTION 'Rate limit exceeded: Maximum 15 connection requests per hour' USING ERRCODE = 'P0001';
    END IF;

    -- Check if connection record already exists
    SELECT * INTO v_existing_conn
    FROM public.attendee_connections
    WHERE event_id = p_event_id
    AND ((requester_id = v_caller_id AND addressee_id = p_peer_id)
         OR (requester_id = p_peer_id AND addressee_id = v_caller_id));

    IF FOUND THEN
        IF v_existing_conn.status = 'pending' THEN
            -- If peer already sent a request to caller, accept it automatically
            IF v_existing_conn.requester_id = p_peer_id THEN
                UPDATE public.attendee_connections
                SET status = 'accepted', updated_at = now()
                WHERE id = v_existing_conn.id
                RETURNING * INTO v_new_conn;

                RETURN jsonb_build_object(
                    'success', true,
                    'status', 'connected',
                    'connection_id', v_new_conn.id,
                    'message', 'Mutual connection accepted!'
                );
            END IF;

            RETURN jsonb_build_object(
                'success', true,
                'status', 'requestSent',
                'connection_id', v_existing_conn.id,
                'message', 'Connection request is already pending'
            );
        ELSIF v_existing_conn.status = 'accepted' THEN
            RETURN jsonb_build_object(
                'success', true,
                'status', 'connected',
                'connection_id', v_existing_conn.id,
                'message', 'Already connected'
            );
        END IF;
    END IF;

    -- Insert new connection request
    INSERT INTO public.attendee_connections (
        event_id,
        requester_id,
        addressee_id,
        status
    ) VALUES (
        p_event_id,
        v_caller_id,
        p_peer_id,
        'pending'
    )
    ON CONFLICT (event_id, LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id))
    DO UPDATE SET 
        status = 'pending',
        requester_id = v_caller_id,
        addressee_id = p_peer_id,
        updated_at = now()
    WHERE public.attendee_connections.status IN ('declined', 'cancelled')
    RETURNING * INTO v_new_conn;

    -- Get caller name for notification
    SELECT full_name INTO v_caller_name FROM public.profiles WHERE id = v_caller_id;

    -- Dispatch in-app notification to addressee
    INSERT INTO public.event_notifications (
        event_id,
        target_user_id,
        title,
        body,
        category,
        action_route
    ) VALUES (
        p_event_id,
        p_peer_id,
        'New Connection Request',
        COALESCE(NULLIF(v_caller_name, ''), 'An attendee') || ' wants to connect with you.',
        'networking',
        '/connect'
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'requestSent',
        'connection_id', v_new_conn.id,
        'message', 'Connection request sent'
    );
END;
$$;

-- 3. RESPOND TO CONNECTION REQUEST (ACCEPT OR DECLINE)
CREATE OR REPLACE FUNCTION public.respond_to_connection_request(
    p_connection_id UUID,
    p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_conn RECORD;
    v_new_status TEXT;
    v_addressee_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_conn
    FROM public.attendee_connections
    WHERE id = p_connection_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Connection request not found' USING ERRCODE = 'P0001';
    END IF;

    IF v_conn.addressee_id <> v_caller_id THEN
        RAISE EXCEPTION 'Only the recipient can respond to this connection request' USING ERRCODE = '42501';
    END IF;

    IF v_conn.status <> 'pending' THEN
        RAISE EXCEPTION 'Connection request is not pending' USING ERRCODE = 'P0001';
    END IF;

    v_new_status := CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END;

    UPDATE public.attendee_connections
    SET status = v_new_status, updated_at = now()
    WHERE id = p_connection_id;

    IF p_accept THEN
        SELECT full_name INTO v_addressee_name FROM public.profiles WHERE id = v_caller_id;

        -- Notify requester of acceptance
        INSERT INTO public.event_notifications (
            event_id,
            target_user_id,
            title,
            body,
            category,
            action_route
        ) VALUES (
            v_conn.event_id,
            v_conn.requester_id,
            'Connection Accepted!',
            COALESCE(NULLIF(v_addressee_name, ''), 'An attendee') || ' accepted your connection request.',
            'networking',
            '/connect'
        );

        -- System welcome message in ephemeral chat
        INSERT INTO public.temporary_chat_messages (
            connection_id,
            event_id,
            sender_id,
            message_text
        ) VALUES (
            p_connection_id,
            v_conn.event_id,
            v_caller_id,
            'You are now connected for this event! Ephemeral messages and suggested meeting points will expire after the event.'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'connection_id', p_connection_id,
        'status', v_new_status
    );
END;
$$;

-- 4. CANCEL CONNECTION REQUEST
CREATE OR REPLACE FUNCTION public.cancel_connection_request(
    p_connection_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_conn RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_conn
    FROM public.attendee_connections
    WHERE id = p_connection_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Connection request not found' USING ERRCODE = 'P0001';
    END IF;

    IF v_conn.requester_id <> v_caller_id THEN
        RAISE EXCEPTION 'Only the sender can cancel this connection request' USING ERRCODE = '42501';
    END IF;

    IF v_conn.status <> 'pending' THEN
        RAISE EXCEPTION 'Can only cancel pending connection requests' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.attendee_connections
    SET status = 'cancelled', updated_at = now()
    WHERE id = p_connection_id;

    RETURN jsonb_build_object(
        'success', true,
        'connection_id', p_connection_id,
        'status', 'cancelled'
    );
END;
$$;

-- 5. SEND CHAT MESSAGE (EPHEMERAL CHAT + MEETING POINT)
CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_connection_id UUID,
    p_message_text TEXT,
    p_meeting_poi_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_conn RECORD;
    v_msg RECORD;
    v_trimmed TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_trimmed := trim(p_message_text);
    IF char_length(v_trimmed) < 1 OR char_length(v_trimmed) > 1000 THEN
        RAISE EXCEPTION 'Message must be between 1 and 1000 characters' USING ERRCODE = 'P0001';
    END IF;

    -- Verify connection exists and is accepted
    SELECT * INTO v_conn
    FROM public.attendee_connections
    WHERE id = p_connection_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Connection not found' USING ERRCODE = 'P0001';
    END IF;

    IF v_conn.status <> 'accepted' THEN
        RAISE EXCEPTION 'Cannot send message: Connection is not accepted' USING ERRCODE = 'P0001';
    END IF;

    IF v_conn.requester_id <> v_caller_id AND v_conn.addressee_id <> v_caller_id THEN
        RAISE EXCEPTION 'Caller is not a participant of this connection' USING ERRCODE = '42501';
    END IF;

    -- Verify event not concluded past grace period (24 hours)
    IF EXISTS (
        SELECT 1 FROM public.events e 
        WHERE e.id = v_conn.event_id 
        AND e.event_end_time IS NOT NULL 
        AND e.event_end_time < (now() - INTERVAL '24 hours')
    ) THEN
        RAISE EXCEPTION 'Cannot send message: Event has concluded' USING ERRCODE = 'P0001';
    END IF;

    -- Verify meeting POI if provided
    IF p_meeting_poi_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.venue_pois vp
            WHERE vp.id = p_meeting_poi_id AND vp.event_id = v_conn.event_id
        ) THEN
            RAISE EXCEPTION 'Invalid meeting POI for this event' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Insert message
    INSERT INTO public.temporary_chat_messages (
        connection_id,
        event_id,
        sender_id,
        message_text,
        meeting_poi_id
    ) VALUES (
        p_connection_id,
        v_conn.event_id,
        v_caller_id,
        v_trimmed,
        p_meeting_poi_id
    ) RETURNING * INTO v_msg;

    -- Update connection last activity
    UPDATE public.attendee_connections
    SET updated_at = now()
    WHERE id = p_connection_id;

    RETURN jsonb_build_object(
        'id', v_msg.id,
        'connectionId', v_msg.connection_id,
        'eventId', v_msg.event_id,
        'senderId', v_msg.sender_id,
        'text', v_msg.message_text,
        'meetingPoiId', v_msg.meeting_poi_id,
        'timestamp', v_msg.created_at
    );
END;
$$;
