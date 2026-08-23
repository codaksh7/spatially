-- supabase/schema.sql

CREATE TABLE observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    ephemeral_id TEXT NOT NULL,
    rssi INTEGER NOT NULL,
    scanned_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_spatially_device BOOLEAN NOT NULL DEFAULT false
);

-- Note: Row Level Security (RLS) is intentionally not enabled for prototype development.
