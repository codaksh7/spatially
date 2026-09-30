-- ============================================================================
-- SPATIALLY — PHASE 5B: MIGRATION (ZONE-LEVEL RLS HARDENING)
-- Author: Senior Software Architect & Backend Security Engineer
-- Date: September 27, 2026
-- Description:
--   Hardens RLS on public.observations and public.volunteer_counts to enforce
--   zone-level authorization:
--     auth.uid() -> volunteer_assignments -> event_id -> authorized zone_id -> allowed write
--   Volunteers assigned to a specific station cannot submit observations or crowd
--   counts for unassigned stations.
-- ============================================================================

-- 1. OBSERVATIONS: ZONE-LEVEL AUTHORIZATION
DROP POLICY IF EXISTS "Volunteers can log crowd observations" ON public.observations;
CREATE POLICY "Volunteers can log crowd observations"
    ON public.observations FOR INSERT
    TO authenticated
    WITH CHECK (
        volunteer_id = auth.uid() AND
        is_spatially_device = true AND -- Privacy constraint: Ambient MAC addresses prohibited
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() 
              AND va.event_id = observations.event_id
              AND va.status = 'active'
              AND (
                  -- If assigned to a specific normalized zone, observation zone MUST match it
                  (va.zone_id IS NOT NULL AND EXISTS (
                      SELECT 1 FROM public.event_zones ez
                      WHERE ez.id = va.zone_id
                        AND (ez.name = observations.zone OR ez.code = observations.zone OR ez.id::text = observations.zone)
                  ))
                  OR
                  -- If event-wide assignment (zone_id is NULL), any zone belonging to that event (or null) is allowed
                  (va.zone_id IS NULL AND (
                      observations.zone IS NULL OR EXISTS (
                          SELECT 1 FROM public.event_zones ez2
                          WHERE ez2.event_id = observations.event_id
                            AND (ez2.name = observations.zone OR ez2.code = observations.zone OR ez2.id::text = observations.zone)
                      )
                      OR EXISTS (
                          SELECT 1 FROM public.events ev
                          WHERE ev.id = observations.event_id
                            AND observations.zone = ANY(ev.zones)
                      )
                  ))
              )
        )
    );

-- 2. VOLUNTEER_COUNTS: ZONE-LEVEL AUTHORIZATION
DROP POLICY IF EXISTS "Volunteers can update zone headcounts" ON public.volunteer_counts;
CREATE POLICY "Volunteers can update zone headcounts"
    ON public.volunteer_counts FOR ALL
    TO authenticated
    USING (
        volunteer_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() 
              AND va.event_id = volunteer_counts.event_id
              AND va.status = 'active'
              AND (
                  -- If assigned to a specific normalized zone, count zone MUST match it
                  (va.zone_id IS NOT NULL AND EXISTS (
                      SELECT 1 FROM public.event_zones ez
                      WHERE ez.id = va.zone_id
                        AND (ez.name = volunteer_counts.zone OR ez.code = volunteer_counts.zone OR ez.id::text = volunteer_counts.zone)
                  ))
                  OR
                  -- If event-wide assignment (zone_id is NULL), any zone belonging to that event is allowed
                  (va.zone_id IS NULL AND (
                      volunteer_counts.zone IS NULL OR EXISTS (
                          SELECT 1 FROM public.event_zones ez2
                          WHERE ez2.event_id = volunteer_counts.event_id
                            AND (ez2.name = volunteer_counts.zone OR ez2.code = volunteer_counts.zone OR ez2.id::text = volunteer_counts.zone)
                      )
                      OR EXISTS (
                          SELECT 1 FROM public.events ev
                          WHERE ev.id = volunteer_counts.event_id
                            AND volunteer_counts.zone = ANY(ev.zones)
                      )
                  ))
              )
        )
    )
    WITH CHECK (
        volunteer_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid() 
              AND va.event_id = volunteer_counts.event_id
              AND va.status = 'active'
              AND (
                  -- If assigned to a specific normalized zone, count zone MUST match it
                  (va.zone_id IS NOT NULL AND EXISTS (
                      SELECT 1 FROM public.event_zones ez
                      WHERE ez.id = va.zone_id
                        AND (ez.name = volunteer_counts.zone OR ez.code = volunteer_counts.zone OR ez.id::text = volunteer_counts.zone)
                  ))
                  OR
                  -- If event-wide assignment (zone_id is NULL), any zone belonging to that event is allowed
                  (va.zone_id IS NULL AND (
                      volunteer_counts.zone IS NULL OR EXISTS (
                          SELECT 1 FROM public.event_zones ez2
                          WHERE ez2.event_id = volunteer_counts.event_id
                            AND (ez2.name = volunteer_counts.zone OR ez2.code = volunteer_counts.zone OR ez2.id::text = volunteer_counts.zone)
                      )
                      OR EXISTS (
                          SELECT 1 FROM public.events ev
                          WHERE ev.id = volunteer_counts.event_id
                            AND volunteer_counts.zone = ANY(ev.zones)
                      )
                  ))
              )
        )
    );
