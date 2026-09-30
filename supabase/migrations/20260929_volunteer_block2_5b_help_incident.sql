-- ==============================================================================
-- SPATIALLY — VOLUNTEER BLOCK 2.5B
-- Operational Help + Incident System Migration
-- ==============================================================================

-- 1. OPERATIONAL INCIDENTS TABLE
CREATE TABLE IF NOT EXISTS public.operational_incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  reporter_type TEXT NOT NULL CHECK (reporter_type IN ('volunteer', 'organizer', 'attendee')),
  reporter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reporter_name TEXT NOT NULL DEFAULT 'Event Staff',
  reporter_device_id TEXT,
  category TEXT NOT NULL CHECK (category IN (
    'crowd',
    'safety',
    'security',
    'medical',
    'infrastructure',
    'equipment',
    'accessibility',
    'lost_found',
    'attendee_assistance',
    'operational',
    'other'
  )),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN (
    'open',
    'acknowledged',
    'assigned',
    'in_progress',
    'resolved',
    'closed',
    'cancelled'
  )),
  title TEXT NOT NULL CHECK (char_length(trim(title)) > 0 AND char_length(title) <= 200),
  description TEXT NOT NULL CHECK (char_length(trim(description)) > 0 AND char_length(description) <= 1000),
  zone_id UUID REFERENCES public.event_zones(id) ON DELETE SET NULL,
  venue_zone_name TEXT,
  venue_poi_id UUID REFERENCES public.venue_pois(id) ON DELETE SET NULL,
  specific_location TEXT,
  assigned_to_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  assigned_to_name TEXT,
  assigned_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  resolution_notes TEXT,
  staff_notes TEXT, -- Private internal staff notes (hidden from attendees)
  image_url TEXT,
  linked_message_id UUID REFERENCES public.operational_messages(id) ON DELETE SET NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. OPERATIONAL INCIDENT AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.operational_incident_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID NOT NULL REFERENCES public.operational_incidents(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_name TEXT NOT NULL DEFAULT 'System',
  action TEXT NOT NULL CHECK (action IN (
    'created',
    'acknowledged',
    'assigned',
    'in_progress',
    'escalated',
    'resolved',
    'closed',
    'cancelled',
    'note_added'
  )),
  previous_status TEXT,
  new_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. INDEXES FOR PERFORMANCE & AUDITING
CREATE INDEX IF NOT EXISTS idx_op_incidents_event_created ON public.operational_incidents(event_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_op_incidents_status ON public.operational_incidents(status);
CREATE INDEX IF NOT EXISTS idx_op_incidents_category ON public.operational_incidents(category);
CREATE INDEX IF NOT EXISTS idx_op_incidents_priority ON public.operational_incidents(priority);
CREATE INDEX IF NOT EXISTS idx_op_incidents_zone ON public.operational_incidents(zone_id);
CREATE INDEX IF NOT EXISTS idx_op_incidents_assigned_to ON public.operational_incidents(assigned_to_id);
CREATE INDEX IF NOT EXISTS idx_op_incidents_reporter ON public.operational_incidents(reporter_id);
CREATE INDEX IF NOT EXISTS idx_op_incidents_device ON public.operational_incidents(reporter_device_id);

CREATE INDEX IF NOT EXISTS idx_op_incident_logs_incident ON public.operational_incident_logs(incident_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_op_incident_logs_event ON public.operational_incident_logs(event_id);

-- 4. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.operational_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operational_incident_logs ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES FOR OPERATIONAL INCIDENTS

-- Policy: Staff can view incidents for their assigned event
DROP POLICY IF EXISTS "Staff can view event operational incidents" ON public.operational_incidents;
CREATE POLICY "Staff can view event operational incidents"
ON public.operational_incidents FOR SELECT
TO authenticated
USING (
  -- User is staff (assigned volunteer or organizer/admin) in the same event
  EXISTS (
    SELECT 1 FROM public.volunteer_assignments va
    WHERE va.volunteer_id = auth.uid() AND va.event_id = operational_incidents.event_id
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
  )
  OR (
    -- Attendee can only see their own submitted requests
    reporter_type = 'attendee' AND reporter_id = auth.uid()
  )
);

-- Policy: Staff can insert incidents
DROP POLICY IF EXISTS "Staff can create operational incidents" ON public.operational_incidents;
CREATE POLICY "Staff can create operational incidents"
ON public.operational_incidents FOR INSERT
TO authenticated
WITH CHECK (
  (
    auth.uid() = reporter_id
    AND (
      EXISTS (
        SELECT 1 FROM public.volunteer_assignments va
        WHERE va.volunteer_id = auth.uid() AND va.event_id = operational_incidents.event_id
      )
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
      )
    )
  )
  OR (
    -- Authenticated attendee submitting assistance request
    reporter_type = 'attendee' AND auth.uid() = reporter_id
  )
);

-- Policy: Staff can update incidents
DROP POLICY IF EXISTS "Staff can update operational incidents" ON public.operational_incidents;
CREATE POLICY "Staff can update operational incidents"
ON public.operational_incidents FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.volunteer_assignments va
    WHERE va.volunteer_id = auth.uid() AND va.event_id = operational_incidents.event_id
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
  )
  OR (
    -- Reporter can cancel their own open request
    reporter_id = auth.uid() AND status = 'open'
  )
);

-- 6. RLS POLICIES FOR OPERATIONAL INCIDENT LOGS
DROP POLICY IF EXISTS "Staff can view incident logs" ON public.operational_incident_logs;
CREATE POLICY "Staff can view incident logs"
ON public.operational_incident_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.volunteer_assignments va
    WHERE va.volunteer_id = auth.uid() AND va.event_id = operational_incident_logs.event_id
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
  )
);

DROP POLICY IF EXISTS "Staff can insert incident logs" ON public.operational_incident_logs;
CREATE POLICY "Staff can insert incident logs"
ON public.operational_incident_logs FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.volunteer_assignments va
    WHERE va.volunteer_id = auth.uid() AND va.event_id = operational_incident_logs.event_id
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin')
  )
);

-- 7. STORAGE BUCKET CONFIGURATION FOR INCIDENT EVIDENCE
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'incident-evidence',
  'incident-evidence',
  true,
  5242880, -- 5 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- Storage policies for incident evidence
DROP POLICY IF EXISTS "Public can view incident evidence" ON storage.objects;
CREATE POLICY "Public can view incident evidence"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'incident-evidence');

DROP POLICY IF EXISTS "Staff can upload incident evidence" ON storage.objects;
CREATE POLICY "Staff can upload incident evidence"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'incident-evidence'
  AND (
    EXISTS (
      SELECT 1 FROM public.volunteer_assignments va
      WHERE va.volunteer_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('organizer', 'admin', 'volunteer')
    )
  )
);

-- 8. PUBLICATION FOR SUPABASE REALTIME
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'operational_incidents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.operational_incidents;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'lost_found_reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.lost_found_reports;
  END IF;
END $$;

-- 9. SECURITY DEFINER RPCS FOR ATOMIC OPERATIONAL ACTIONS

-- RPC: Report Operational Incident
CREATE OR REPLACE FUNCTION public.report_operational_incident(
  p_event_id UUID,
  p_category TEXT,
  p_priority TEXT,
  p_title TEXT,
  p_description TEXT,
  p_zone_id UUID DEFAULT NULL,
  p_venue_zone_name TEXT DEFAULT NULL,
  p_venue_poi_id UUID DEFAULT NULL,
  p_specific_location TEXT DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_link_operational_message BOOLEAN DEFAULT false,
  p_reporter_type TEXT DEFAULT 'volunteer',
  p_reporter_device_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_reporter_name TEXT := 'Staff Member';
  v_user_role TEXT := 'volunteer';
  v_incident_id UUID;
  v_linked_message_id UUID := NULL;
  v_zone_name TEXT := p_venue_zone_name;
BEGIN
  -- Authenticate if not guest attendee
  IF p_reporter_type IN ('volunteer', 'organizer') THEN
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'Authentication required to report staff incident';
    END IF;

    -- Verify event assignment or role
    SELECT full_name, role INTO v_reporter_name, v_user_role
    FROM public.profiles WHERE id = v_user_id;

    IF v_user_role NOT IN ('organizer', 'admin') THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.volunteer_assignments
        WHERE volunteer_id = v_user_id AND event_id = p_event_id
      ) THEN
        RAISE EXCEPTION 'Not authorized for this event';
      END IF;
    END IF;
  ELSE
    -- Attendee reporter
    IF v_user_id IS NOT NULL THEN
      SELECT full_name, role INTO v_reporter_name, v_user_role
      FROM public.profiles WHERE id = v_user_id;
    ELSE
      v_reporter_name := 'Event Attendee';
    END IF;
  END IF;

  -- Resolve zone name if null and zone_id provided
  IF v_zone_name IS NULL AND p_zone_id IS NOT NULL THEN
    SELECT name INTO v_zone_name FROM public.event_zones WHERE id = p_zone_id;
  END IF;

  -- Insert Incident
  INSERT INTO public.operational_incidents (
    event_id,
    reporter_type,
    reporter_id,
    reporter_name,
    reporter_device_id,
    category,
    priority,
    status,
    title,
    description,
    zone_id,
    venue_zone_name,
    venue_poi_id,
    specific_location,
    image_url,
    created_at,
    updated_at
  ) VALUES (
    p_event_id,
    p_reporter_type,
    v_user_id,
    v_reporter_name,
    p_reporter_device_id,
    p_category,
    p_priority,
    'open',
    p_title,
    p_description,
    p_zone_id,
    v_zone_name,
    p_venue_poi_id,
    p_specific_location,
    p_image_url,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  ) RETURNING id INTO v_incident_id;

  -- Log action
  INSERT INTO public.operational_incident_logs (
    incident_id,
    event_id,
    actor_id,
    actor_name,
    action,
    new_status,
    notes
  ) VALUES (
    v_incident_id,
    p_event_id,
    v_user_id,
    v_reporter_name,
    'created',
    'open',
    'Incident reported: ' || p_title
  );

  -- Link operational message if requested or if priority is urgent
  IF (p_link_operational_message OR p_priority = 'urgent') AND v_user_id IS NOT NULL THEN
    INSERT INTO public.operational_messages (
      event_id,
      sender_id,
      sender_role,
      sender_name,
      target_type,
      priority,
      message_type,
      requires_acknowledgment,
      body,
      metadata
    ) VALUES (
      p_event_id,
      v_user_id,
      v_user_role,
      v_reporter_name,
      'organizer',
      p_priority,
      'escalation',
      p_priority = 'urgent',
      '[' || UPPER(p_category) || '] ' || p_title || ': ' || p_description || COALESCE(' (' || v_zone_name || ')', ''),
      jsonb_build_object('incident_id', v_incident_id, 'category', p_category)
    ) RETURNING id INTO v_linked_message_id;

    UPDATE public.operational_incidents
    SET linked_message_id = v_linked_message_id
    WHERE id = v_incident_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'incident_id', v_incident_id,
    'linked_message_id', v_linked_message_id,
    'status', 'open'
  );
END;
$$;

-- RPC: Assign Operational Incident (Atomic, Race-Condition Protected)
CREATE OR REPLACE FUNCTION public.assign_operational_incident(
  p_incident_id UUID,
  p_assigned_to_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_actor_name TEXT;
  v_assignee_name TEXT;
  v_incident RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Lock row for update to prevent concurrent race condition
  SELECT * INTO v_incident
  FROM public.operational_incidents
  WHERE id = p_incident_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  -- Check if already assigned to someone else
  IF v_incident.assigned_to_id IS NOT NULL AND v_incident.assigned_to_id <> p_assigned_to_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'ALREADY_ASSIGNED',
      'assigned_to_name', v_incident.assigned_to_name
    );
  END IF;

  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_user_id;
  SELECT full_name INTO v_assignee_name FROM public.profiles WHERE id = p_assigned_to_id;

  -- Update assignment
  UPDATE public.operational_incidents
  SET assigned_to_id = p_assigned_to_id,
      assigned_to_name = v_assignee_name,
      assigned_at = timezone('utc'::text, now()),
      status = 'assigned',
      updated_at = timezone('utc'::text, now())
  WHERE id = p_incident_id;

  -- Log action
  INSERT INTO public.operational_incident_logs (
    incident_id,
    event_id,
    actor_id,
    actor_name,
    action,
    previous_status,
    new_status,
    notes
  ) VALUES (
    p_incident_id,
    v_incident.event_id,
    v_user_id,
    COALESCE(v_actor_name, 'Staff'),
    'assigned',
    v_incident.status,
    'assigned',
    'Assigned to ' || COALESCE(v_assignee_name, 'staff member')
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', 'assigned',
    'assigned_to_id', p_assigned_to_id,
    'assigned_to_name', v_assignee_name
  );
END;
$$;

-- RPC: Acknowledge Operational Incident
CREATE OR REPLACE FUNCTION public.acknowledge_operational_incident(
  p_incident_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_actor_name TEXT;
  v_incident RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_incident FROM public.operational_incidents WHERE id = p_incident_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_user_id;

  UPDATE public.operational_incidents
  SET acknowledged_at = timezone('utc'::text, now()),
      status = CASE WHEN status = 'open' THEN 'acknowledged' ELSE status END,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_incident_id;

  INSERT INTO public.operational_incident_logs (
    incident_id,
    event_id,
    actor_id,
    actor_name,
    action,
    previous_status,
    new_status,
    notes
  ) VALUES (
    p_incident_id,
    v_incident.event_id,
    v_user_id,
    COALESCE(v_actor_name, 'Staff'),
    'acknowledged',
    v_incident.status,
    CASE WHEN v_incident.status = 'open' THEN 'acknowledged' ELSE v_incident.status END,
    'Acknowledged by staff'
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: Update Incident Status (Resolve, Close, In Progress, Cancel)
CREATE OR REPLACE FUNCTION public.update_incident_status(
  p_incident_id UUID,
  p_new_status TEXT,
  p_resolution_notes TEXT DEFAULT NULL,
  p_staff_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_actor_name TEXT;
  v_incident RECORD;
  v_resolved_at TIMESTAMPTZ := NULL;
  v_closed_at TIMESTAMPTZ := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_incident FROM public.operational_incidents WHERE id = p_incident_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
  END IF;

  SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = v_user_id;

  IF p_new_status = 'resolved' THEN
    v_resolved_at := timezone('utc'::text, now());
  ELSIF p_new_status = 'closed' THEN
    v_closed_at := timezone('utc'::text, now());
    IF v_incident.resolved_at IS NULL THEN
      v_resolved_at := timezone('utc'::text, now());
    END IF;
  END IF;

  UPDATE public.operational_incidents
  SET status = p_new_status,
      resolved_at = COALESCE(v_resolved_at, resolved_at),
      closed_at = COALESCE(v_closed_at, closed_at),
      resolution_notes = COALESCE(p_resolution_notes, resolution_notes),
      staff_notes = CASE
        WHEN p_staff_notes IS NOT NULL AND staff_notes IS NOT NULL
          THEN staff_notes || E'\n[' || to_char(now(), 'YYYY-MM-DD HH24:MI') || ' ' || COALESCE(v_actor_name, 'Staff') || ']: ' || p_staff_notes
        WHEN p_staff_notes IS NOT NULL
          THEN '[' || to_char(now(), 'YYYY-MM-DD HH24:MI') || ' ' || COALESCE(v_actor_name, 'Staff') || ']: ' || p_staff_notes
        ELSE staff_notes
      END,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_incident_id;

  INSERT INTO public.operational_incident_logs (
    incident_id,
    event_id,
    actor_id,
    actor_name,
    action,
    previous_status,
    new_status,
    notes
  ) VALUES (
    p_incident_id,
    v_incident.event_id,
    v_user_id,
    COALESCE(v_actor_name, 'Staff'),
    CASE
      WHEN p_new_status = 'resolved' THEN 'resolved'
      WHEN p_new_status = 'closed' THEN 'closed'
      WHEN p_new_status = 'cancelled' THEN 'cancelled'
      ELSE 'in_progress'
    END,
    v_incident.status,
    p_new_status,
    COALESCE(p_resolution_notes, p_staff_notes, 'Status changed to ' || p_new_status)
  );

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;

-- RPC: Request Attendee Assistance (Attendee Safe Ingress)
CREATE OR REPLACE FUNCTION public.request_attendee_assistance(
  p_event_id UUID,
  p_category TEXT,
  p_title TEXT,
  p_description TEXT,
  p_zone_id UUID DEFAULT NULL,
  p_venue_zone_name TEXT DEFAULT NULL,
  p_specific_location TEXT DEFAULT NULL,
  p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_reporter_name TEXT := 'Attendee';
  v_priority TEXT := 'normal';
  v_incident_id UUID;
BEGIN
  -- Determine priority
  IF p_category IN ('medical', 'security') THEN
    v_priority := 'urgent';
  ELSIF p_category = 'accessibility' THEN
    v_priority := 'important';
  END IF;

  IF v_user_id IS NOT NULL THEN
    SELECT full_name INTO v_reporter_name FROM public.profiles WHERE id = v_user_id;
  END IF;

  INSERT INTO public.operational_incidents (
    event_id,
    reporter_type,
    reporter_id,
    reporter_name,
    reporter_device_id,
    category,
    priority,
    status,
    title,
    description,
    zone_id,
    venue_zone_name,
    specific_location,
    created_at,
    updated_at
  ) VALUES (
    p_event_id,
    'attendee',
    v_user_id,
    COALESCE(v_reporter_name, 'Attendee'),
    p_device_id,
    p_category,
    v_priority,
    'open',
    p_title,
    p_description,
    p_zone_id,
    p_venue_zone_name,
    p_specific_location,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  ) RETURNING id INTO v_incident_id;

  INSERT INTO public.operational_incident_logs (
    incident_id,
    event_id,
    actor_id,
    actor_name,
    action,
    new_status,
    notes
  ) VALUES (
    v_incident_id,
    p_event_id,
    v_user_id,
    COALESCE(v_reporter_name, 'Attendee'),
    'created',
    'open',
    'Attendee requested assistance: ' || p_title
  );

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_incident_id,
    'priority', v_priority,
    'status', 'open'
  );
END;
$$;

-- RPC: Get Attendee Assistance Status (Attendee Safe, no staff notes)
CREATE OR REPLACE FUNCTION public.get_attendee_assistance_status(
  p_event_id UUID,
  p_device_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  category TEXT,
  priority TEXT,
  status TEXT,
  title TEXT,
  description TEXT,
  venue_zone_name TEXT,
  assigned_to_name TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  resolution_notes TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    oi.id,
    oi.category,
    oi.priority,
    oi.status,
    oi.title,
    oi.description,
    oi.venue_zone_name,
    oi.assigned_to_name,
    oi.created_at,
    oi.updated_at,
    oi.resolution_notes
  FROM public.operational_incidents oi
  WHERE oi.event_id = p_event_id
    AND oi.reporter_type = 'attendee'
    AND (
      (auth.uid() IS NOT NULL AND oi.reporter_id = auth.uid())
      OR (p_device_id IS NOT NULL AND oi.reporter_device_id = p_device_id)
    )
  ORDER BY oi.created_at DESC;
$$;

-- RPC: Update Lost & Found Report Status (Staff Controlled)
CREATE OR REPLACE FUNCTION public.update_lost_found_status(
  p_report_id UUID,
  p_new_status TEXT,
  p_pickup_instructions TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.lost_found_reports
  SET status = p_new_status,
      pickup_instructions = COALESCE(p_pickup_instructions, pickup_instructions),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_report_id;

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;
