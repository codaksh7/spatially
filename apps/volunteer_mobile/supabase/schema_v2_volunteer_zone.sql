ALTER TABLE observations ADD COLUMN volunteer_id UUID REFERENCES auth.users(id);
ALTER TABLE observations ADD COLUMN zone TEXT;
