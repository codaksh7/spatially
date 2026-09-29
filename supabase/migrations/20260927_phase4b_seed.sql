-- ============================================================================
-- SPATIALLY — PHASE 4B: MIGRATION 6 (REALISTIC SEED DATA)
-- Author: Senior Software Architect & Backend Engineer
-- Date: September 27, 2026
-- Description: Seeds authoritative venue topology (6 zones, 12 POIs),
--              sessions, booths, activities, and initial notifications
--              for the live/upcoming events matching the Attendee mobile app.
-- ============================================================================

DO $$
DECLARE
    v_event_id UUID;
    v_z701 UUID;
    v_z702 UUID;
    v_z706 UUID;
    v_z707 UUID;
    v_z711 UUID;
    v_z712 UUID;
    v_poi_stage_a UUID;
    v_poi_stage_pres UUID;
    v_poi_b1 UUID;
    v_poi_b2 UUID;
    v_poi_b3 UUID;
    v_poi_b4 UUID;
    v_poi_b5 UUID;
    v_poi_b6 UUID;
    v_poi_help UUID;
    v_poi_first_aid UUID;
    v_poi_security UUID;
    v_poi_access UUID;
BEGIN
    -- Select primary live/upcoming event: 'Project Presentation' or first live/upcoming
    SELECT id INTO v_event_id 
    FROM public.events 
    WHERE name ILIKE '%Project Presentation%' 
    ORDER BY created_at DESC 
    LIMIT 1;

    IF v_event_id IS NULL THEN
        SELECT id INTO v_event_id FROM public.events LIMIT 1;
    END IF;

    IF v_event_id IS NULL THEN
        RAISE NOTICE 'No existing event found to seed data.';
        RETURN;
    END IF;

    -- Update event banner_url and timestamps
    UPDATE public.events 
    SET 
        banner_url = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200&auto=format&fit=crop&q=80',
        event_start_time = timezone('utc'::text, now() - INTERVAL '2 hours'),
        event_end_time = timezone('utc'::text, now() + INTERVAL '10 hours')
    WHERE id = v_event_id;

    -- ========================================================================
    -- 1. SEED EVENT ZONES (6 zones matching venue_mock_data.dart)
    -- ========================================================================
    INSERT INTO public.event_zones (event_id, code, name, floor_level, capacity_limit, current_density)
    VALUES (v_event_id, '701', 'Auditorium', 1, 250, 'moderate')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.event_zones (event_id, code, name, floor_level, capacity_limit, current_density)
    VALUES (v_event_id, '702', 'Project Exhibition Hall A', 1, 150, 'high')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.event_zones (event_id, code, name, floor_level, capacity_limit, current_density)
    VALUES (v_event_id, '706', 'Project Exhibition Hall B', 1, 120, 'low')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.event_zones (event_id, code, name, floor_level, capacity_limit, current_density)
    VALUES (v_event_id, '707', 'Workshop & Labs', 1, 60, 'low')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.event_zones (event_id, code, name, floor_level, capacity_limit, current_density)
    VALUES (v_event_id, '711', 'Seminar Room', 1, 50, 'moderate')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.event_zones (event_id, code, name, floor_level, capacity_limit, current_density)
    VALUES (v_event_id, '712', 'Foyer & Registration', 1, 200, 'low')
    ON CONFLICT DO NOTHING;

    SELECT id INTO v_z701 FROM public.event_zones WHERE event_id = v_event_id AND code = '701';
    SELECT id INTO v_z702 FROM public.event_zones WHERE event_id = v_event_id AND code = '702';
    SELECT id INTO v_z706 FROM public.event_zones WHERE event_id = v_event_id AND code = '706';
    SELECT id INTO v_z707 FROM public.event_zones WHERE event_id = v_event_id AND code = '707';
    SELECT id INTO v_z711 FROM public.event_zones WHERE event_id = v_event_id AND code = '711';
    SELECT id INTO v_z712 FROM public.event_zones WHERE event_id = v_event_id AND code = '712';

    -- ========================================================================
    -- 2. SEED VENUE POIS
    -- ========================================================================
    INSERT INTO public.venue_pois (id, event_id, zone_id, name, category, x_coordinate, y_coordinate, floor_level, description)
    VALUES 
        ('00000000-0000-0000-0000-000000000001'::uuid, v_event_id, v_z701, 'Stage A', 'stage', 0.18, 0.48, 1, 'Keynote auditorium stage with AV broadcast'),
        ('00000000-0000-0000-0000-000000000002'::uuid, v_event_id, v_z702, 'Presentation Stage', 'stage', 0.70, 0.62, 1, 'Technical presentation stage in Hall A'),
        ('00000000-0000-0000-0000-000000000003'::uuid, v_event_id, v_z702, 'Spatially Core Booth', 'booth', 0.85, 0.55, 1, 'Interactive spatial computing & BLE telemetry showcase'),
        ('00000000-0000-0000-0000-000000000004'::uuid, v_event_id, v_z702, 'BeaconGrid Booth', 'booth', 0.85, 0.65, 1, 'Hardware beacons & enterprise radio hardware'),
        ('00000000-0000-0000-0000-000000000005'::uuid, v_event_id, v_z702, 'Horizon Robotics Booth', 'booth', 0.65, 0.70, 1, 'Autonomous indoor pathfinding showcase'),
        ('00000000-0000-0000-0000-000000000006'::uuid, v_event_id, v_z706, 'CyberPulse Booth', 'booth', 0.85, 0.25, 1, 'Zero-knowledge networking & privacy solutions'),
        ('00000000-0000-0000-0000-000000000007'::uuid, v_event_id, v_z706, 'HyperScale Cloud Booth', 'booth', 0.85, 0.35, 1, 'High-throughput edge stream processing'),
        ('00000000-0000-0000-0000-000000000008'::uuid, v_event_id, v_z706, 'NextGen Design Labs Booth', 'booth', 0.65, 0.25, 1, 'Spatial design tokens & interactive micro-UIs'),
        ('00000000-0000-0000-0000-000000000009'::uuid, v_event_id, v_z712, 'Central Help Desk', 'help', 0.35, 0.82, 1, 'Information, badge replacement, and Lost & Found dispatch'),
        ('00000000-0000-0000-0000-000000000010'::uuid, v_event_id, v_z712, 'First Aid & Medical', 'medical', 0.50, 0.82, 1, 'Licensed paramedic station with emergency response equipment'),
        ('00000000-0000-0000-0000-000000000011'::uuid, v_event_id, v_z712, 'Security Operations', 'security', 0.65, 0.82, 1, 'On-site venue safety and operations desk'),
        ('00000000-0000-0000-0000-000000000012'::uuid, v_event_id, v_z712, 'Accessibility Station', 'accessibility', 0.28, 0.82, 1, 'Assistance and sensory-friendly navigation aids')
    ON CONFLICT (id) DO UPDATE SET 
        name = EXCLUDED.name,
        category = EXCLUDED.category,
        x_coordinate = EXCLUDED.x_coordinate,
        y_coordinate = EXCLUDED.y_coordinate;

    -- ========================================================================
    -- 3. SEED SESSIONS (Matching EventContentMockData)
    -- ========================================================================
    INSERT INTO public.sessions (id, event_id, zone_id, title, description, speaker_name, speaker_role, stage_name, start_time, end_time, tags, is_live)
    VALUES 
        (
            '10000000-0000-0000-0000-000000000001'::uuid,
            v_event_id, v_z701,
            'Spatial Intelligence & The Next Era of Physical Perception',
            'Opening keynote addressing non-invasive spatial computing, BLE mesh topologies, and real-time localized event analytics.',
            'Dr. Elena Vance', 'Lead AI Researcher @ Spatially Labs',
            'Room 701 • Auditorium Stage A',
            timezone('utc'::text, now() - INTERVAL '30 minutes'),
            timezone('utc'::text, now() + INTERVAL '45 minutes'),
            ARRAY['Keynote', 'Spatial AI', 'BLE Mesh', 'Privacy'],
            true
        ),
        (
            '10000000-0000-0000-0000-000000000002'::uuid,
            v_event_id, v_z707,
            'Hands-on BLE Mesh & Peripheral Infrastructure',
            'Deep dive workshop on low-energy Bluetooth advertising protocols, rotating cryptographic hashes, and mobile listener design.',
            'Marcus Chen', 'Principal Systems Engineer @ BeaconGrid',
            'Room 707 • Workshop & Labs',
            timezone('utc'::text, now() + INTERVAL '1 hour'),
            timezone('utc'::text, now() + INTERVAL '2 hours 30 minutes'),
            ARRAY['Workshop', 'Hardware', 'Bluetooth', 'Embedded'],
            false
        ),
        (
            '10000000-0000-0000-0000-000000000003'::uuid,
            v_event_id, v_z702,
            'Autonomous Spatial Wayfinding & Indoor Robotics',
            'A technical showcase demonstrating graph-based indoor pathfinding algorithms and dynamic barrier avoidance using micro-sensors.',
            'Sarah Jenkins', 'Hardware Engineering Lead @ Horizon',
            'Room 702 • Presentation Stage',
            timezone('utc'::text, now() + INTERVAL '3 hours'),
            timezone('utc'::text, now() + INTERVAL '3 hours 45 minutes'),
            ARRAY['Robotics', 'Wayfinding', 'Autonomous'],
            false
        ),
        (
            '10000000-0000-0000-0000-000000000004'::uuid,
            v_event_id, v_z711,
            'The Privacy Frontier: Ephemeral IDs & Non-Invasive Sensing',
            'Industry panelists debate the ethics and engineering realities of preserving attendee anonymity while capturing aggregate venue intelligence.',
            'Aiden Patel (Moderator)', 'Head of Product Security @ PrivacyFirst',
            'Room 711 • Seminar Room',
            timezone('utc'::text, now() + INTERVAL '4 hours 30 minutes'),
            timezone('utc'::text, now() + INTERVAL '5 hours 30 minutes'),
            ARRAY['Panel', 'Security', 'Ethics', 'Zero-Knowledge'],
            false
        )
    ON CONFLICT (id) DO UPDATE SET 
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        is_live = EXCLUDED.is_live;

    -- ========================================================================
    -- 4. SEED BOOTHS (Matching EventContentMockData)
    -- ========================================================================
    INSERT INTO public.booths (id, event_id, zone_id, name, company_name, booth_number, description, category, contact_email, website_url)
    VALUES 
        (
            '20000000-0000-0000-0000-000000000001'::uuid,
            v_event_id, v_z702,
            'Spatially Labs Interactive Experience',
            'Spatially Labs', 'B-101',
            'Live demonstration of non-invasive BLE micro-telemetry, edge-computed heatmaps, and spatial guidance.',
            'Spatial Computing', 'team@spatially.app', 'https://spatially.app'
        ),
        (
            '20000000-0000-0000-0000-000000000002'::uuid,
            v_event_id, v_z702,
            'BeaconGrid Hardware Showcase',
            'BeaconGrid Networks', 'B-102',
            'Industrial-grade iBeacon, Eddystone, and ultra-wideband micro-beacons engineered for large-scale venues.',
            'IoT & Hardware', 'info@beacongrid.io', 'https://beacongrid.io'
        ),
        (
            '20000000-0000-0000-0000-000000000003'::uuid,
            v_event_id, v_z706,
            'Horizon Robotics Arena',
            'Horizon Automations', 'B-201',
            'Interactive indoor robotics demo navigating obstacle courses in real time using sensor fusion.',
            'Robotics & AI', 'hello@horizonauto.com', 'https://horizonauto.com'
        ),
        (
            '20000000-0000-0000-0000-000000000004'::uuid,
            v_event_id, v_z706,
            'CyberPulse Privacy Vault',
            'CyberPulse Security', 'B-202',
            'Zero-knowledge authentication and privacy-preserving networking architecture demos.',
            'Cybersecurity', 'security@cyberpulse.net', 'https://cyberpulse.net'
        )
    ON CONFLICT (id) DO UPDATE SET 
        name = EXCLUDED.name,
        description = EXCLUDED.description;

    -- ========================================================================
    -- 5. SEED ACTIVITIES (Engagement Engine)
    -- ========================================================================
    INSERT INTO public.activities (id, event_id, zone_id, title, description, activity_type, points_reward, is_active)
    VALUES 
        (
            '30000000-0000-0000-0000-000000000001'::uuid,
            v_event_id, v_z702,
            'Spatial Beacon Scavenger Hunt',
            'Locate and verify all 4 specialized beacon checkpoints across Exhibition Hall A and Hall B.',
            'scavenger', 50, true
        ),
        (
            '30000000-0000-0000-0000-000000000002'::uuid,
            v_event_id, v_z707,
            'BLE Mesh Configuration Challenge',
            'Configure a 3-node peripheral BLE mesh cluster during the hands-on lab.',
            'workshop', 75, true
        ),
        (
            '30000000-0000-0000-0000-000000000003'::uuid,
            v_event_id, v_z711,
            'Privacy & Zero-Knowledge Architecture Quiz',
            'Test your comprehension of zero-knowledge proofs and rotating cryptographic salts.',
            'contest', 30, true
        )
    ON CONFLICT (id) DO UPDATE SET 
        title = EXCLUDED.title,
        description = EXCLUDED.description;

    -- ========================================================================
    -- 6. SEED EVENT NOTIFICATIONS (Announcements & Safety Alerts)
    -- ========================================================================
    INSERT INTO public.event_notifications (id, event_id, title, body, category, is_active, created_at)
    VALUES 
        (
            '40000000-0000-0000-0000-000000000001'::uuid,
            v_event_id,
            'Keynote starting in 15 minutes',
            '“Spatial Intelligence & The Next Era of Physical Perception” begins shortly in Room 701 Auditorium.',
            'schedule', true, timezone('utc'::text, now() - INTERVAL '10 minutes')
        ),
        (
            '40000000-0000-0000-0000-000000000002'::uuid,
            v_event_id,
            'Venue Operational Notice: Hall A Access',
            'West doors of Exhibition Hall A are temporarily staff-only for equipment staging. Please use the North entrance.',
            'safety', true, timezone('utc'::text, now() - INTERVAL '25 minutes')
        ),
        (
            '40000000-0000-0000-0000-000000000003'::uuid,
            v_event_id,
            'Welcome to Spatially Live Experience',
            'Explore the interactive floorplan in Map, visit partner booths in Exhibition Hall A, and unlock badges in Passport.',
            'general', true, timezone('utc'::text, now() - INTERVAL '1 hour')
        )
    ON CONFLICT (id) DO UPDATE SET 
        title = EXCLUDED.title,
        body = EXCLUDED.body;

    -- ========================================================================
    -- 7. SEED VOLUNTEER LIVE COUNT (For Realtime test)
    -- ========================================================================
    INSERT INTO public.volunteer_counts (volunteer_id, event_id, zone, active_count, updated_at)
    VALUES 
        ('ae30ee77-e9fc-494f-84b2-9a93910b7ddc'::uuid, v_event_id, '702', 42, timezone('utc'::text, now())),
        ('73015e90-8dbd-4422-88f0-d3fd48a29a8a'::uuid, v_event_id, '701', 88, timezone('utc'::text, now()))
    ON CONFLICT (volunteer_id) DO UPDATE SET 
        active_count = EXCLUDED.active_count,
        event_id = EXCLUDED.event_id,
        zone = EXCLUDED.zone,
        updated_at = EXCLUDED.updated_at;

END $$;
