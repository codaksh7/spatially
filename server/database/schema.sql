-- Spatially Web Platform Schema Migration
-- Run this in Supabase SQL Editor after the mobile app schemas (v1-v4)

-- Extend events table with web platform columns
ALTER TABLE events ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE events ADD COLUMN IF NOT EXISTS capacity INTEGER DEFAULT 0;
ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_id TEXT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_name TEXT DEFAULT '';
ALTER TABLE events ADD COLUMN IF NOT EXISTS start_time TIME;
ALTER TABLE events ADD COLUMN IF NOT EXISTS end_time TIME;
ALTER TABLE events ADD COLUMN IF NOT EXISTS location_address TEXT DEFAULT '';

-- Web Users table for unified web authentication
CREATE TABLE IF NOT EXISTS web_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    user_type TEXT NOT NULL CHECK (user_type IN ('user', 'volunteer', 'organizer')),
    full_name TEXT NOT NULL DEFAULT '',
    nickname TEXT DEFAULT '',
    is_verified BOOLEAN DEFAULT FALSE,
    verification_token TEXT,
    verification_token_expires TIMESTAMPTZ,
    reset_token TEXT,
    reset_token_expires TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_web_users_email ON web_users(email);
CREATE INDEX IF NOT EXISTS idx_web_users_user_id ON web_users(user_id);
CREATE INDEX IF NOT EXISTS idx_web_users_user_type ON web_users(user_type);

-- Event invitations sent by organizers to volunteers
CREATE TABLE IF NOT EXISTS event_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    volunteer_email TEXT NOT NULL,
    volunteer_user_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    invited_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_invitations_event ON event_invitations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_email ON event_invitations(volunteer_email);

-- Web volunteer assignments (separate from mobile app volunteer_assignments)
CREATE TABLE IF NOT EXISTS web_volunteer_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_user_id TEXT NOT NULL,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    zone TEXT,
    assigned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(volunteer_user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_web_vol_assign_vol ON web_volunteer_assignments(volunteer_user_id);
CREATE INDEX IF NOT EXISTS idx_web_vol_assign_event ON web_volunteer_assignments(event_id);

-- User event registrations (attendee web registrations)
CREATE TABLE IF NOT EXISTS user_event_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    registered_at TIMESTAMPTZ DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'registered' CHECK (status IN ('registered', 'cancelled')),
    UNIQUE(user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_user_registrations_user ON user_event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_registrations_event ON user_event_registrations(event_id);

-- RLS disabled for prototype development (consistent with mobile app tables)
ALTER TABLE web_users DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_invitations DISABLE ROW LEVEL SECURITY;
ALTER TABLE web_volunteer_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_event_registrations DISABLE ROW LEVEL SECURITY;
