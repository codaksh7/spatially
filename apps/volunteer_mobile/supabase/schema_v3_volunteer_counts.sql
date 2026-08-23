CREATE TABLE volunteer_counts (
    volunteer_id UUID PRIMARY KEY REFERENCES auth.users(id),
    zone TEXT,
    active_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
