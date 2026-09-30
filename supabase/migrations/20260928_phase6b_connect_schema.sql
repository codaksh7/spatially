-- ============================================================================
-- SPATIALLY — PHASE 6B: MIGRATION 1 (CONNECT SCHEMA & INDEXES)
-- Author: Senior Software Architect & Supabase Backend Engineer
-- Date: September 28, 2026
-- Target: Spatially Attendee Mobile + Supabase Backend (bajrtiiqwqvblnbtuhvw)
-- Description: Adds networking preferences to profiles, creates event-scoped
--              attendee_connections and temporary_chat_messages tables with
--              integrity constraints and performance indexes.
-- ============================================================================

-- 1. EXTEND PUBLIC.PROFILES WITH NETWORKING PREFERENCES
-- Note: Default for networking_opt_in is set to FALSE to uphold privacy-safe
-- defaults for existing users until they explicitly enable networking in-app.
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS networking_opt_in BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS networking_visibility TEXT NOT NULL DEFAULT 'matchingInterests',
ADD COLUMN IF NOT EXISTS allow_proximity_discovery BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS location_note TEXT DEFAULT '';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_profiles_networking_visibility'
    ) THEN
        ALTER TABLE public.profiles
        ADD CONSTRAINT chk_profiles_networking_visibility
        CHECK (networking_visibility IN ('discoverable', 'matchingInterests', 'invisible'));
    END IF;
END $$;

-- 2. CREATE PUBLIC.ATTENDEE_CONNECTIONS
-- Event-scoped bilateral connection requests and mutual opt-in states.
CREATE TABLE IF NOT EXISTS public.attendee_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_no_self_connection CHECK (requester_id <> addressee_id)
);

-- Unique pair constraint per event: prevents duplicate bidirectional requests (A->B and B->A)
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendee_connections_pair 
ON public.attendee_connections (
    event_id, 
    LEAST(requester_id, addressee_id), 
    GREATEST(requester_id, addressee_id)
);

-- Foreign key & query filtering indexes
CREATE INDEX IF NOT EXISTS idx_attendee_connections_event 
ON public.attendee_connections(event_id);

CREATE INDEX IF NOT EXISTS idx_attendee_connections_requester 
ON public.attendee_connections(requester_id);

CREATE INDEX IF NOT EXISTS idx_attendee_connections_addressee 
ON public.attendee_connections(addressee_id);

CREATE INDEX IF NOT EXISTS idx_attendee_connections_status 
ON public.attendee_connections(status);

CREATE INDEX IF NOT EXISTS idx_attendee_connections_user_event
ON public.attendee_connections(event_id, requester_id, addressee_id);

-- 3. CREATE PUBLIC.TEMPORARY_CHAT_MESSAGES
-- Ephemeral event-scoped chat messages linked to an accepted connection.
CREATE TABLE IF NOT EXISTS public.temporary_chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_id UUID NOT NULL REFERENCES public.attendee_connections(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    meeting_poi_id UUID REFERENCES public.venue_pois(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_message_length CHECK (char_length(message_text) BETWEEN 1 AND 1000)
);

-- Chronological conversation index
CREATE INDEX IF NOT EXISTS idx_chat_messages_conn_created 
ON public.temporary_chat_messages(connection_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_event 
ON public.temporary_chat_messages(event_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender 
ON public.temporary_chat_messages(sender_id);
