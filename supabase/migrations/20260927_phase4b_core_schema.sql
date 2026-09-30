-- ============================================================================
-- SPATIALLY — PHASE 4B: MIGRATION 1 (CORE SCHEMA & RECONCILIATION)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description: Establishes the 11 locked domain tables, reconciles existing
--              tables (events, tickets, volunteer_assignments), and preserves
--              operational infrastructure (volunteer_counts, observations).
-- ============================================================================

-- Ensure uuid-ossp and pgcrypto extensions are active
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. PUBLIC.PROFILES (New Core Identity Table)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'attendee' CHECK (role IN ('attendee', 'volunteer', 'organizer', 'admin')),
    headline TEXT,
    bio TEXT,
    interests TEXT[] NOT NULL DEFAULT '{}',
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 2. RECONCILE PUBLIC.EVENTS
-- ============================================================================
-- Preserve existing columns (id, name, venue, event_date, status, zones, etc.)
-- Ensure start_time and end_time support TIMESTAMPTZ or proper time representation
-- Add banner_url, metadata if absent
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_start_time TIMESTAMPTZ;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_end_time TIMESTAMPTZ;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- ============================================================================
-- 3. RECONCILE PUBLIC.TICKETS (Dual-Ownership Architecture)
-- ============================================================================
-- attendee_id stores the local guest device UUID.
-- user_id links to auth.users(id) once claimed.
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS claim_hash TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

-- ============================================================================
-- 4. PUBLIC.EVENT_ZONES (Normalized Venue Topology)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.event_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    floor_level INTEGER NOT NULL DEFAULT 1,
    capacity_limit INTEGER NOT NULL DEFAULT 200,
    current_density TEXT NOT NULL DEFAULT 'low' CHECK (current_density IN ('low', 'moderate', 'high', 'critical')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 5. PUBLIC.VENUE_POIS (Normalized Points of Interest)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.venue_pois (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'stage', 'booth', 'restroom', 'food', 'water', 'help', 
        'medical', 'security', 'accessibility', 'emergency_exit', 'other'
    )),
    x_coordinate DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    y_coordinate DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    floor_level INTEGER NOT NULL DEFAULT 1,
    description TEXT,
    accessibility_flags TEXT[] DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 6. PUBLIC.SESSIONS (Schedule Content)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    poi_id UUID REFERENCES public.venue_pois(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    speaker_name TEXT NOT NULL,
    speaker_role TEXT,
    stage_name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    tags TEXT[] NOT NULL DEFAULT '{}',
    is_live BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 7. PUBLIC.BOOTHS (Exhibitors & Partners)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.booths (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    poi_id UUID REFERENCES public.venue_pois(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    company_name TEXT NOT NULL,
    booth_number TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'General',
    contact_email TEXT,
    website_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 8. PUBLIC.ACTIVITIES (Engagement Engine Content)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    poi_id UUID REFERENCES public.venue_pois(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    activity_type TEXT NOT NULL CHECK (activity_type IN ('workshop', 'contest', 'scavenger', 'networking', 'keynote', 'game')),
    points_reward INTEGER NOT NULL DEFAULT 10,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 9. PUBLIC.LOST_FOUND_REPORTS (Safety & Lost Property)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.lost_found_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    reporter_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reporter_device_id TEXT NOT NULL,
    report_type TEXT NOT NULL CHECK (report_type IN ('lost', 'found')),
    category TEXT NOT NULL CHECK (category IN ('electronics', 'wallet', 'id_card', 'bag', 'clothing', 'keys', 'other')),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
    venue_zone_name TEXT,
    specific_location TEXT,
    image_url TEXT,
    status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'in_review', 'matched', 'resolved')),
    pickup_instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 10. PUBLIC.EVENT_NOTIFICATIONS (Announcements & Safety Alerts)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.event_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL indicates broadcast to all
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('urgent', 'schedule', 'crowd', 'safety', 'general', 'networking', 'engagement')),
    action_route TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMPTZ
);

-- ============================================================================
-- 11. RECONCILE PUBLIC.VOLUNTEER_ASSIGNMENTS
-- ============================================================================
-- Already exists with volunteer_id UUID, event_id UUID, assigned_at TIMESTAMPTZ.
-- Add zone_id, shift times, role, and status.
ALTER TABLE public.volunteer_assignments ADD COLUMN IF NOT EXISTS zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL;
ALTER TABLE public.volunteer_assignments ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'crowd_monitor';
ALTER TABLE public.volunteer_assignments ADD COLUMN IF NOT EXISTS shift_start TIMESTAMPTZ;
ALTER TABLE public.volunteer_assignments ADD COLUMN IF NOT EXISTS shift_end TIMESTAMPTZ;
ALTER TABLE public.volunteer_assignments ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'reassigned'));

-- ============================================================================
-- 12. POPULATE PROFILES FOR EXISTING AUTH.USERS
-- ============================================================================
INSERT INTO public.profiles (id, email, full_name, role)
SELECT 
    u.id, 
    u.email, 
    COALESCE(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1)),
    CASE 
        WHEN u.raw_user_meta_data->>'user_type' = 'volunteer' THEN 'volunteer'
        WHEN u.raw_user_meta_data->>'user_type' = 'organizer' THEN 'organizer'
        WHEN u.email LIKE '%@spatially.app' THEN 'admin'
        ELSE 'attendee'
    END
FROM auth.users u
ON CONFLICT (id) DO NOTHING;
