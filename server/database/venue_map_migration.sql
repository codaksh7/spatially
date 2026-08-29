-- Venue Map Migration for Spatially Web Platform
-- Run this in Supabase SQL Editor

-- Volunteer map positions: where organizer places each volunteer on the 2D map
CREATE TABLE IF NOT EXISTS volunteer_map_positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    volunteer_user_id TEXT NOT NULL,
    zone TEXT NOT NULL,
    pos_x FLOAT DEFAULT 50,
    pos_y FLOAT DEFAULT 50,
    assigned_by TEXT NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, volunteer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_vol_map_pos_event ON volunteer_map_positions(event_id);
CREATE INDEX IF NOT EXISTS idx_vol_map_pos_vol ON volunteer_map_positions(volunteer_user_id);

-- Volunteer switch requests: V1 asks V2 to swap positions
CREATE TABLE IF NOT EXISTS volunteer_switch_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    requester_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_switch_req_event ON volunteer_switch_requests(event_id);
CREATE INDEX IF NOT EXISTS idx_switch_req_target ON volunteer_switch_requests(target_id);
CREATE INDEX IF NOT EXISTS idx_switch_req_requester ON volunteer_switch_requests(requester_id);

-- Disable RLS for prototype (consistent with other tables)
ALTER TABLE volunteer_map_positions DISABLE ROW LEVEL SECURITY;
ALTER TABLE volunteer_switch_requests DISABLE ROW LEVEL SECURITY;
