-- ============================================================================
-- SPATIALLY — PHASE 7A-1: SPATIAL TOPOLOGY & SCHEMA MIGRATION
-- Target: Hosted Supabase PostgreSQL 17 (bajrtiiqwqvblnbtuhvw)
-- Purpose: Safely establish reusable, multi-level spatial topology foundation
-- Invariants:
--   1. 100% additive and backward-compatible.
--   2. All existing PKs and UUIDs preserved.
--   3. All existing foreign keys preserved.
--   4. RLS enabled on all new tables with public read and staff management.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CREATE TABLE: public.venues
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.venues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    venue_type TEXT NOT NULL DEFAULT 'multi_floor'
        CHECK (venue_type IN ('single_level', 'multi_floor', 'outdoor', 'hybrid')),
    address TEXT,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 2. CREATE TABLE: public.venue_levels
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.venue_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
    level_index INTEGER NOT NULL,
    name TEXT NOT NULL,
    short_code TEXT NOT NULL,
    level_type TEXT NOT NULL DEFAULT 'indoor_floor'
        CHECK (level_type IN ('indoor_floor', 'outdoor_ground', 'mezzanine', 'parking', 'rooftop')),
    map_asset_url TEXT,
    aspect_ratio DOUBLE PRECISION NOT NULL DEFAULT 1.25,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_venue_level_index UNIQUE (venue_id, level_index)
);

-- ----------------------------------------------------------------------------
-- 3. CREATE TABLE: public.venue_zones
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.venue_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
    level_id UUID NOT NULL REFERENCES public.venue_levels(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    structural_capacity INTEGER CHECK (structural_capacity IS NULL OR structural_capacity > 0),
    bounds JSONB NOT NULL DEFAULT '{"left":0.0,"top":0.0,"width":0.2,"height":0.2}'::jsonb,
    polygon JSONB,
    entrance_point JSONB NOT NULL DEFAULT '{"x":0.1,"y":0.1}'::jsonb,
    is_accessible BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_venue_zone_code UNIQUE (venue_id, code)
);

-- ----------------------------------------------------------------------------
-- 4. EXTEND TABLE: public.events
-- ----------------------------------------------------------------------------
ALTER TABLE public.events
ADD COLUMN IF NOT EXISTS venue_id UUID REFERENCES public.venues(id) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- 5. EXTEND TABLE: public.event_zones
-- ----------------------------------------------------------------------------
ALTER TABLE public.event_zones
ADD COLUMN IF NOT EXISTS venue_zone_id UUID REFERENCES public.venue_zones(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS level_id UUID REFERENCES public.venue_levels(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS bounds JSONB DEFAULT '{"left":0.0,"top":0.0,"width":0.2,"height":0.2}'::jsonb,
ADD COLUMN IF NOT EXISTS entrance_point JSONB DEFAULT '{"x":0.1,"y":0.1}'::jsonb,
ADD COLUMN IF NOT EXISTS operating_capacity INTEGER,
ADD COLUMN IF NOT EXISTS warning_threshold DOUBLE PRECISION NOT NULL DEFAULT 0.80,
ADD COLUMN IF NOT EXISTS critical_threshold DOUBLE PRECISION NOT NULL DEFAULT 0.90,
ADD COLUMN IF NOT EXISTS is_crowd_monitored BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS operational_status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS status_reason TEXT,
ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT true;

-- Add check constraints to event_zones if not already present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_event_zone_operational_status'
    ) THEN
        ALTER TABLE public.event_zones
        ADD CONSTRAINT chk_event_zone_operational_status 
        CHECK (operational_status IN ('active', 'closed', 'restricted', 'emergency_only'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_event_zone_thresholds'
    ) THEN
        ALTER TABLE public.event_zones
        ADD CONSTRAINT chk_event_zone_thresholds 
        CHECK (warning_threshold > 0 AND warning_threshold < critical_threshold AND critical_threshold <= 1.0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_event_zone_operating_capacity'
    ) THEN
        ALTER TABLE public.event_zones
        ADD CONSTRAINT chk_event_zone_operating_capacity 
        CHECK (operating_capacity IS NULL OR operating_capacity > 0);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 6. EXTEND TABLE: public.venue_pois
-- ----------------------------------------------------------------------------
-- First allow event_id to be nullable so permanent POIs can exist without an event
ALTER TABLE public.venue_pois
ALTER COLUMN event_id DROP NOT NULL;

-- Add spatial topology columns
ALTER TABLE public.venue_pois
ADD COLUMN IF NOT EXISTS venue_id UUID REFERENCES public.venues(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS level_id UUID REFERENCES public.venue_levels(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS is_permanent BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS operational_status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT true;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_venue_poi_operational_status'
    ) THEN
        ALTER TABLE public.venue_pois
        ADD CONSTRAINT chk_venue_poi_operational_status 
        CHECK (operational_status IN ('active', 'out_of_service', 'restricted', 'blocked'));
    END IF;

    -- Update category check constraint to support vertical connectors and event facilities
    ALTER TABLE public.venue_pois
    DROP CONSTRAINT IF EXISTS venue_pois_category_check;

    ALTER TABLE public.venue_pois
    ADD CONSTRAINT venue_pois_category_check 
    CHECK (category = ANY (ARRAY[
        'stage'::text, 
        'booth'::text, 
        'restroom'::text, 
        'food'::text, 
        'water'::text, 
        'help'::text, 
        'medical'::text, 
        'security'::text, 
        'accessibility'::text, 
        'emergency_exit'::text, 
        'elevator'::text, 
        'stairs'::text, 
        'escalator'::text, 
        'ramp'::text, 
        'entrance'::text, 
        'workshop'::text, 
        'charging'::text, 
        'assembly_point'::text, 
        'other'::text
    ]));

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_venue_poi_scope'
    ) THEN
        ALTER TABLE public.venue_pois
        ADD CONSTRAINT chk_venue_poi_scope 
        CHECK ((is_permanent = true AND venue_id IS NOT NULL) OR (is_permanent = false AND event_id IS NOT NULL));
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 7. INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_events_venue_id ON public.events(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_levels_venue_id ON public.venue_levels(venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_zones_venue_level ON public.venue_zones(venue_id, level_id);
CREATE INDEX IF NOT EXISTS idx_venue_zones_code ON public.venue_zones(code);
CREATE INDEX IF NOT EXISTS idx_event_zones_venue_zone ON public.event_zones(venue_zone_id);
CREATE INDEX IF NOT EXISTS idx_event_zones_level_id ON public.event_zones(level_id);
CREATE INDEX IF NOT EXISTS idx_venue_pois_venue_level ON public.venue_pois(venue_id, level_id);
CREATE INDEX IF NOT EXISTS idx_venue_pois_is_permanent ON public.venue_pois(is_permanent);
CREATE INDEX IF NOT EXISTS idx_venue_pois_is_published ON public.venue_pois(is_published);

-- ----------------------------------------------------------------------------
-- 8. ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------
ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_zones ENABLE ROW LEVEL SECURITY;

-- Venues: Public can view, Staff can manage
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'venues' AND policyname = 'Public can view venues'
    ) THEN
        CREATE POLICY "Public can view venues" ON public.venues FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'venues' AND policyname = 'Staff can manage venues'
    ) THEN
        CREATE POLICY "Staff can manage venues" ON public.venues FOR ALL TO authenticated
        USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ANY (ARRAY['organizer'::text, 'admin'::text])));
    END IF;
END $$;

-- Venue Levels: Public can view, Staff can manage
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'venue_levels' AND policyname = 'Public can view venue levels'
    ) THEN
        CREATE POLICY "Public can view venue levels" ON public.venue_levels FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'venue_levels' AND policyname = 'Staff can manage venue levels'
    ) THEN
        CREATE POLICY "Staff can manage venue levels" ON public.venue_levels FOR ALL TO authenticated
        USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ANY (ARRAY['organizer'::text, 'admin'::text])));
    END IF;
END $$;

-- Venue Zones: Public can view, Staff can manage
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'venue_zones' AND policyname = 'Public can view venue zones'
    ) THEN
        CREATE POLICY "Public can view venue zones" ON public.venue_zones FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'venue_zones' AND policyname = 'Staff can manage venue zones'
    ) THEN
        CREATE POLICY "Staff can manage venue zones" ON public.venue_zones FOR ALL TO authenticated
        USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ANY (ARRAY['organizer'::text, 'admin'::text])));
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 9. DATA RECONCILIATION & SEEDING FOR EXISTING VENUE/EVENT
-- ----------------------------------------------------------------------------
-- A. Insert permanent venue
INSERT INTO public.venues (id, name, slug, venue_type, address, timezone, metadata)
VALUES (
    '00000000-0000-0000-0001-000000000001',
    'FCRCE Campus',
    'fcrce-campus',
    'multi_floor',
    'Fr. Conceicao Rodrigues College of Engineering, Bandra (W), Mumbai',
    'Asia/Kolkata',
    '{"institution": "FCRCE", "campus_code": "MAIN"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    address = EXCLUDED.address,
    updated_at = timezone('utc'::text, now());

-- B. Insert venue levels
-- Level 0: Ground Floor & Open Quad
INSERT INTO public.venue_levels (id, venue_id, level_index, name, short_code, level_type, display_order)
VALUES (
    '00000000-0000-0000-0002-000000000000',
    '00000000-0000-0000-0001-000000000001',
    0,
    'Ground Floor & Open Quad',
    'G',
    'outdoor_ground',
    0
)
ON CONFLICT (venue_id, level_index) DO UPDATE SET
    name = EXCLUDED.name,
    short_code = EXCLUDED.short_code;

-- Level 1: 7th Floor Presentation & Exhibition Complex
INSERT INTO public.venue_levels (id, venue_id, level_index, name, short_code, level_type, display_order)
VALUES (
    '00000000-0000-0000-0002-000000000001',
    '00000000-0000-0000-0001-000000000001',
    1,
    '7th Floor - Presentation & Exhibition Complex',
    'L7',
    'indoor_floor',
    1
)
ON CONFLICT (venue_id, level_index) DO UPDATE SET
    name = EXCLUDED.name,
    short_code = EXCLUDED.short_code;

-- C. Insert physical venue_zones for 7th Floor
-- Room 701: Auditorium
INSERT INTO public.venue_zones (id, venue_id, level_id, code, name, structural_capacity, bounds, entrance_point, is_accessible)
VALUES (
    'a0000000-0000-0000-0003-000000000701',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '701',
    'Auditorium',
    250,
    '{"left": 0.06, "top": 0.30, "width": 0.34, "height": 0.40}'::jsonb,
    '{"x": 0.40, "y": 0.50}'::jsonb,
    true
)
ON CONFLICT (venue_id, code) DO UPDATE SET
    bounds = EXCLUDED.bounds,
    entrance_point = EXCLUDED.entrance_point,
    structural_capacity = EXCLUDED.structural_capacity;

-- Room 702: Project Exhibition Hall A
INSERT INTO public.venue_zones (id, venue_id, level_id, code, name, structural_capacity, bounds, entrance_point, is_accessible)
VALUES (
    'a0000000-0000-0000-0003-000000000702',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '702',
    'Project Exhibition Hall A',
    150,
    '{"left": 0.60, "top": 0.50, "width": 0.34, "height": 0.26}'::jsonb,
    '{"x": 0.60, "y": 0.62}'::jsonb,
    true
)
ON CONFLICT (venue_id, code) DO UPDATE SET
    bounds = EXCLUDED.bounds,
    entrance_point = EXCLUDED.entrance_point,
    structural_capacity = EXCLUDED.structural_capacity;

-- Room 706: Project Exhibition Hall B
INSERT INTO public.venue_zones (id, venue_id, level_id, code, name, structural_capacity, bounds, entrance_point, is_accessible)
VALUES (
    'a0000000-0000-0000-0003-000000000706',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '706',
    'Project Exhibition Hall B',
    120,
    '{"left": 0.60, "top": 0.20, "width": 0.34, "height": 0.26}'::jsonb,
    '{"x": 0.60, "y": 0.34}'::jsonb,
    true
)
ON CONFLICT (venue_id, code) DO UPDATE SET
    bounds = EXCLUDED.bounds,
    entrance_point = EXCLUDED.entrance_point,
    structural_capacity = EXCLUDED.structural_capacity;

-- Room 707: Workshop & Labs
INSERT INTO public.venue_zones (id, venue_id, level_id, code, name, structural_capacity, bounds, entrance_point, is_accessible)
VALUES (
    'a0000000-0000-0000-0003-000000000707',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '707',
    'Workshop & Labs',
    60,
    '{"left": 0.06, "top": 0.08, "width": 0.34, "height": 0.18}'::jsonb,
    '{"x": 0.40, "y": 0.18}'::jsonb,
    true
)
ON CONFLICT (venue_id, code) DO UPDATE SET
    bounds = EXCLUDED.bounds,
    entrance_point = EXCLUDED.entrance_point,
    structural_capacity = EXCLUDED.structural_capacity;

-- Room 711: Seminar Room
INSERT INTO public.venue_zones (id, venue_id, level_id, code, name, structural_capacity, bounds, entrance_point, is_accessible)
VALUES (
    'a0000000-0000-0000-0003-000000000711',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '711',
    'Seminar Room',
    50,
    '{"left": 0.42, "top": 0.05, "width": 0.16, "height": 0.14}'::jsonb,
    '{"x": 0.50, "y": 0.19}'::jsonb,
    true
)
ON CONFLICT (venue_id, code) DO UPDATE SET
    bounds = EXCLUDED.bounds,
    entrance_point = EXCLUDED.entrance_point,
    structural_capacity = EXCLUDED.structural_capacity;

-- Room 712: Foyer & Registration
INSERT INTO public.venue_zones (id, venue_id, level_id, code, name, structural_capacity, bounds, entrance_point, is_accessible)
VALUES (
    'a0000000-0000-0000-0003-000000000712',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '712',
    'Foyer & Registration',
    200,
    '{"left": 0.22, "top": 0.74, "width": 0.56, "height": 0.18}'::jsonb,
    '{"x": 0.50, "y": 0.74}'::jsonb,
    true
)
ON CONFLICT (venue_id, code) DO UPDATE SET
    bounds = EXCLUDED.bounds,
    entrance_point = EXCLUDED.entrance_point,
    structural_capacity = EXCLUDED.structural_capacity;

-- D. Reconcile existing events with venue
UPDATE public.events
SET venue_id = '00000000-0000-0000-0001-000000000001'
WHERE id = '63ed3709-1b92-4438-9bf3-4a860f3f1846'
   OR venue ILIKE '%7th Floor%'
   OR venue ILIKE '%FCRCE%';

-- E. Reconcile existing event_zones with venue_zones, level_id, bounds, entrance_point, operating_capacity
UPDATE public.event_zones ez
SET 
    venue_zone_id = vz.id,
    level_id = vz.level_id,
    bounds = vz.bounds,
    entrance_point = vz.entrance_point,
    operating_capacity = vz.structural_capacity,
    operational_status = 'active',
    is_published = true
FROM public.venue_zones vz
WHERE vz.venue_id = '00000000-0000-0000-0001-000000000001'
  AND vz.code = ez.code;

-- F. Reconcile existing venue_pois with venue_id, level_id
UPDATE public.venue_pois
SET 
    venue_id = '00000000-0000-0000-0001-000000000001',
    level_id = '00000000-0000-0000-0002-000000000001',
    operational_status = 'active',
    is_published = true
WHERE venue_id IS NULL;

-- G. Seed permanent vertical connectors on Level 1
-- Main Elevator Bank
INSERT INTO public.venue_pois (
    id,
    venue_id,
    level_id,
    zone_id,
    name,
    category,
    x_coordinate,
    y_coordinate,
    floor_level,
    description,
    accessibility_flags,
    is_active,
    is_permanent,
    operational_status,
    is_published,
    metadata
)
VALUES (
    '00000000-0000-0000-0000-000000000021',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    '89bff6d1-c32e-4a59-8f50-a132a3fd6c83', -- In Room 712 Foyer
    'Central Elevator Bank (Lifts 1-3)',
    'elevator',
    0.50,
    0.88,
    1,
    'Main passenger elevator bank connecting Ground Floor to 7th Floor presentation complex.',
    ARRAY['step_free', 'wheelchair_accessible'],
    true,
    true,
    'active',
    true,
    '{"connector_group_id": "central_elevators", "connector_type": "elevator", "connected_level_indices": [0, 1], "is_step_free": true, "directionality": "bidirectional"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    metadata = EXCLUDED.metadata;

-- North Fire & Emergency Staircase
INSERT INTO public.venue_pois (
    id,
    venue_id,
    level_id,
    zone_id,
    name,
    category,
    x_coordinate,
    y_coordinate,
    floor_level,
    description,
    accessibility_flags,
    is_active,
    is_permanent,
    operational_status,
    is_published,
    metadata
)
VALUES (
    '00000000-0000-0000-0000-000000000022',
    '00000000-0000-0000-0001-000000000001',
    '00000000-0000-0000-0002-000000000001',
    'ecdf11c3-52b3-41da-b72f-074226f7877f', -- Near Seminar Room 711
    'North Enclosed Staircase (Emergency Egress)',
    'stairs',
    0.50,
    0.04,
    1,
    'Enclosed fire-rated staircase providing primary emergency evacuation route to Ground Level assembly.',
    ARRAY['emergency_egress'],
    true,
    true,
    'active',
    true,
    '{"connector_group_id": "north_stairwell", "connector_type": "stairs", "connected_level_indices": [0, 1], "is_step_free": false, "directionality": "bidirectional"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    metadata = EXCLUDED.metadata;
