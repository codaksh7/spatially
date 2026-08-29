-- Activity Logs Migration for Spatially Web Platform
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS event_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    description TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_activity_logs_event ON event_activity_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_event_activity_logs_created ON event_activity_logs(created_at DESC);

-- Disable RLS for prototype (consistent with other tables)
ALTER TABLE event_activity_logs DISABLE ROW LEVEL SECURITY;
