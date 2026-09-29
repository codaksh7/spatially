-- ============================================================================
-- SPATIALLY — PHASE 4B: MIGRATION 5 (REALTIME PUBLICATION)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description: Adds volunteer_counts and event_notifications to supabase_realtime.
-- ============================================================================

-- Enable full replication identities for reliable CDC
ALTER TABLE public.volunteer_counts REPLICA IDENTITY FULL;
ALTER TABLE public.event_notifications REPLICA IDENTITY FULL;

-- Add to publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.volunteer_counts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.event_notifications;
