-- ============================================================================
-- SPATIALLY — PHASE 4B: MIGRATION 2 (INDEXES & CONSTRAINTS)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description: Establishes performance indexes across all 11 domain tables
--              and existing operational tables (volunteer_counts, observations).
-- ============================================================================

-- Events indexes
CREATE INDEX IF NOT EXISTS idx_events_status ON public.events(status);
CREATE INDEX IF NOT EXISTS idx_events_date ON public.events(event_date);

-- Tickets indexes
CREATE INDEX IF NOT EXISTS idx_tickets_event_id ON public.tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_tickets_attendee_id ON public.tickets(attendee_id);
CREATE INDEX IF NOT EXISTS idx_tickets_user_id ON public.tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_ticket_code ON public.tickets(ticket_code);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON public.tickets(status);

-- Event Zones indexes
CREATE INDEX IF NOT EXISTS idx_event_zones_event_id ON public.event_zones(event_id);
CREATE INDEX IF NOT EXISTS idx_event_zones_code ON public.event_zones(code);

-- Venue POIs indexes
CREATE INDEX IF NOT EXISTS idx_venue_pois_event_id ON public.venue_pois(event_id);
CREATE INDEX IF NOT EXISTS idx_venue_pois_zone_id ON public.venue_pois(zone_id);
CREATE INDEX IF NOT EXISTS idx_venue_pois_category ON public.venue_pois(category);

-- Sessions indexes
CREATE INDEX IF NOT EXISTS idx_sessions_event_id ON public.sessions(event_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON public.sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_sessions_zone_id ON public.sessions(zone_id);
CREATE INDEX IF NOT EXISTS idx_sessions_is_live ON public.sessions(is_live);

-- Booths indexes
CREATE INDEX IF NOT EXISTS idx_booths_event_id ON public.booths(event_id);
CREATE INDEX IF NOT EXISTS idx_booths_zone_id ON public.booths(zone_id);
CREATE INDEX IF NOT EXISTS idx_booths_category ON public.booths(category);

-- Activities indexes
CREATE INDEX IF NOT EXISTS idx_activities_event_id ON public.activities(event_id);
CREATE INDEX IF NOT EXISTS idx_activities_zone_id ON public.activities(zone_id);
CREATE INDEX IF NOT EXISTS idx_activities_type ON public.activities(activity_type);

-- Lost & Found Reports indexes
CREATE INDEX IF NOT EXISTS idx_lost_found_event_id ON public.lost_found_reports(event_id);
CREATE INDEX IF NOT EXISTS idx_lost_found_type ON public.lost_found_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_lost_found_status ON public.lost_found_reports(status);
CREATE INDEX IF NOT EXISTS idx_lost_found_device ON public.lost_found_reports(reporter_device_id);
CREATE INDEX IF NOT EXISTS idx_lost_found_user ON public.lost_found_reports(reporter_user_id);
CREATE INDEX IF NOT EXISTS idx_lost_found_created_at ON public.lost_found_reports(created_at DESC);

-- Event Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_event_id ON public.event_notifications(event_id);
CREATE INDEX IF NOT EXISTS idx_notifications_target_user ON public.event_notifications(target_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_category ON public.event_notifications(category);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.event_notifications(created_at DESC);

-- Volunteer Assignments indexes
CREATE INDEX IF NOT EXISTS idx_volunteer_assignments_volunteer ON public.volunteer_assignments(volunteer_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_assignments_event ON public.volunteer_assignments(event_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_assignments_zone ON public.volunteer_assignments(zone_id);

-- Operational tables indexes
CREATE INDEX IF NOT EXISTS idx_volunteer_counts_event ON public.volunteer_counts(event_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_counts_zone ON public.volunteer_counts(zone);
CREATE INDEX IF NOT EXISTS idx_observations_event_scanned ON public.observations(event_id, scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_observations_ephemeral ON public.observations(ephemeral_id);
