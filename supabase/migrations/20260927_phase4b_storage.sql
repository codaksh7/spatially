-- ============================================================================
-- SPATIALLY — PHASE 4B: MIGRATION 4 (STORAGE BUCKETS & POLICIES)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description: Establishes event-assets, venue-maps, and lost-found-images
--              storage buckets with explicit public-read and authenticated-write
--              policies. Precludes direct anonymous writes to lost-found-images.
-- ============================================================================

-- Create buckets if not present
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('event-assets', 'event-assets', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']),
    ('venue-maps', 'venue-maps', true, 10485760, ARRAY['image/svg+xml', 'application/json', 'application/geo+json']),
    ('lost-found-images', 'lost-found-images', true, 3145728, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET 
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage Policies for event-assets
DROP POLICY IF EXISTS "Public can view event assets" ON storage.objects;
CREATE POLICY "Public can view event assets"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'event-assets');

DROP POLICY IF EXISTS "Staff can upload event assets" ON storage.objects;
CREATE POLICY "Staff can upload event assets"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'event-assets' AND
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin'))
    );

-- Storage Policies for venue-maps
DROP POLICY IF EXISTS "Public can view venue maps" ON storage.objects;
CREATE POLICY "Public can view venue maps"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'venue-maps');

DROP POLICY IF EXISTS "Staff can upload venue maps" ON storage.objects;
CREATE POLICY "Staff can upload venue maps"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'venue-maps' AND
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('organizer', 'admin'))
    );

-- Storage Policies for lost-found-images
DROP POLICY IF EXISTS "Public can view lost and found photos" ON storage.objects;
CREATE POLICY "Public can view lost and found photos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'lost-found-images');

-- Direct upload restricted to authenticated users & volunteers
DROP POLICY IF EXISTS "Authenticated users and staff can upload lost and found photos" ON storage.objects;
CREATE POLICY "Authenticated users and staff can upload lost and found photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'lost-found-images'
    );
