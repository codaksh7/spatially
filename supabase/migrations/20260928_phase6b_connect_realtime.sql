-- ============================================================================
-- SPATIALLY — PHASE 6B: MIGRATION 4 (CONNECT REALTIME CONFIGURATION)
-- Author: Senior Software Architect & Supabase Backend Engineer
-- Date: September 28, 2026
-- Target: Spatially Attendee Mobile + Supabase Backend (bajrtiiqwqvblnbtuhvw)
-- Description: Adds attendee_connections and temporary_chat_messages to
--              supabase_realtime publication and configures replica identities.
-- ============================================================================

-- 1. SET REPLICA IDENTITY FULL (ensures UPDATE / DELETE emit complete row payloads)
ALTER TABLE public.attendee_connections REPLICA IDENTITY FULL;
ALTER TABLE public.temporary_chat_messages REPLICA IDENTITY FULL;

-- 2. ADD TO SUPABASE REALTIME PUBLICATION
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'attendee_connections'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.attendee_connections;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'temporary_chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.temporary_chat_messages;
    END IF;
END $$;
