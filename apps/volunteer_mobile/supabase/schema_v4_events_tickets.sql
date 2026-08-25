-- supabase/schema_v4_events_tickets.sql

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    venue TEXT,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'upcoming',  -- 'upcoming' | 'live' | 'ended'
    zones TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id),
    attendee_id UUID NOT NULL,              -- local device UUID, no auth.users FK
    ticket_code TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'purchased',  -- 'purchased' | 'checked_in'
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    checked_in_at TIMESTAMP WITH TIME ZONE,
    checked_in_by UUID REFERENCES auth.users(id)
);

CREATE TABLE volunteer_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID NOT NULL REFERENCES auth.users(id),
    event_id UUID NOT NULL REFERENCES events(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE observations ADD COLUMN event_id UUID REFERENCES events(id);
ALTER TABLE volunteer_counts ADD COLUMN event_id UUID REFERENCES events(id);

-- Note: RLS intentionally left disabled, consistent with existing tables (prototype development).
