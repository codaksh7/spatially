-- ============================================================================
-- SPATIALLY — PHASE 6B: MIGRATION 2 (CONNECT ROW LEVEL SECURITY)
-- Author: Senior Software Architect & Supabase Backend Engineer
-- Date: September 28, 2026
-- Target: Spatially Attendee Mobile + Supabase Backend (bajrtiiqwqvblnbtuhvw)
-- Description: Enables Row Level Security on attendee_connections and
--              temporary_chat_messages, establishing strict bilateral
--              ownership, event-scoping, and ticket authorization policies.
-- ============================================================================

-- 1. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.attendee_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temporary_chat_messages ENABLE ROW LEVEL SECURITY;

-- 2. RLS POLICIES FOR PUBLIC.ATTENDEE_CONNECTIONS

-- SELECT: Only the requester or addressee can view the connection record.
DROP POLICY IF EXISTS "Participants can view their own connections" ON public.attendee_connections;
CREATE POLICY "Participants can view their own connections"
    ON public.attendee_connections FOR SELECT
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- INSERT: Authenticated attendee can initiate request only if both have active tickets,
-- target has opted in, and event has not ended beyond 24h grace period.
DROP POLICY IF EXISTS "Authenticated users can create connection requests" ON public.attendee_connections;
CREATE POLICY "Authenticated users can create connection requests"
    ON public.attendee_connections FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = requester_id
        AND status = 'pending'
        AND requester_id <> addressee_id
        -- Event must not be ended past grace period (24 hours)
        AND EXISTS (
            SELECT 1 FROM public.events e 
            WHERE e.id = event_id 
            AND (e.event_end_time IS NULL OR e.event_end_time >= now() - INTERVAL '24 hours')
        )
        -- Requester must hold an active ticket for event_id
        AND EXISTS (
            SELECT 1 FROM public.tickets t 
            WHERE t.event_id = attendee_connections.event_id 
            AND t.user_id = auth.uid() 
            AND t.status IN ('purchased', 'checked_in')
        )
        -- Addressee must hold an active ticket for event_id
        AND EXISTS (
            SELECT 1 FROM public.tickets t 
            WHERE t.event_id = attendee_connections.event_id 
            AND t.user_id = attendee_connections.addressee_id 
            AND t.status IN ('purchased', 'checked_in')
        )
        -- Addressee must have networking enabled and not be invisible
        AND EXISTS (
            SELECT 1 FROM public.profiles p 
            WHERE p.id = attendee_connections.addressee_id 
            AND p.networking_opt_in = true 
            AND p.networking_visibility <> 'invisible'
        )
    );

-- UPDATE: Addressee can transition pending -> accepted / declined;
-- Requester can transition pending -> cancelled.
DROP POLICY IF EXISTS "Participants can update connection state" ON public.attendee_connections;
CREATE POLICY "Participants can update connection state"
    ON public.attendee_connections FOR UPDATE
    TO authenticated
    USING (
        auth.uid() IS NOT NULL AND (
            (auth.uid() = addressee_id AND status = 'pending')
            OR
            (auth.uid() = requester_id AND status = 'pending')
        )
    )
    WITH CHECK (
        auth.uid() IS NOT NULL AND (
            (auth.uid() = addressee_id AND status IN ('accepted', 'declined'))
            OR
            (auth.uid() = requester_id AND status = 'cancelled')
        )
    );

-- 3. RLS POLICIES FOR PUBLIC.TEMPORARY_CHAT_MESSAGES

-- SELECT: Only participants of an accepted connection can read messages.
DROP POLICY IF EXISTS "Participants can view messages for accepted connections" ON public.temporary_chat_messages;
CREATE POLICY "Participants can view messages for accepted connections"
    ON public.temporary_chat_messages FOR SELECT
    TO authenticated
    USING (
        auth.uid() IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.attendee_connections ac
            WHERE ac.id = temporary_chat_messages.connection_id
            AND ac.status = 'accepted'
            AND (ac.requester_id = auth.uid() OR ac.addressee_id = auth.uid())
        )
    );

-- INSERT: Only participants of an accepted connection can send messages,
-- sender_id must match auth.uid(), and event has not ended past grace period.
DROP POLICY IF EXISTS "Participants can insert messages in accepted connections" ON public.temporary_chat_messages;
CREATE POLICY "Participants can insert messages in accepted connections"
    ON public.temporary_chat_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.attendee_connections ac
            WHERE ac.id = temporary_chat_messages.connection_id
            AND ac.status = 'accepted'
            AND ac.event_id = temporary_chat_messages.event_id
            AND (ac.requester_id = auth.uid() OR ac.addressee_id = auth.uid())
        )
        AND EXISTS (
            SELECT 1 FROM public.events e
            WHERE e.id = temporary_chat_messages.event_id
            AND (e.event_end_time IS NULL OR e.event_end_time >= now() - INTERVAL '24 hours')
        )
    );
