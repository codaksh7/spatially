-- ============================================================================
-- SPATIALLY — VOLUNTEER BLOCK 2.5A: OPERATIONAL COMMUNICATION CORE
-- Migration: 20260929_volunteer_block2_5a_communication.sql
-- Description: Creates operational_messages, operational_message_receipts,
--              RLS policies, directory & acknowledgment RPCs, and Realtime CDC.
-- ============================================================================

-- 1. Create public.operational_messages
CREATE TABLE IF NOT EXISTS public.operational_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('volunteer', 'organizer', 'admin')),
    sender_name TEXT NOT NULL,
    target_type TEXT NOT NULL CHECK (target_type IN ('event', 'zone', 'volunteer', 'organizer')),
    target_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL for event/organizer-pool broadcasts
    zone_id UUID REFERENCES public.event_zones(id) ON DELETE CASCADE, -- For zone-targeted communications
    message_type TEXT NOT NULL DEFAULT 'operational' CHECK (message_type IN ('broadcast', 'direct', 'operational', 'quick_reply', 'escalation')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
    body TEXT NOT NULL CHECK (char_length(trim(body)) > 0 AND char_length(body) <= 1000),
    requires_acknowledgment BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_operational_messages_event_created 
    ON public.operational_messages (event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_operational_messages_target 
    ON public.operational_messages (event_id, target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_operational_messages_sender 
    ON public.operational_messages (event_id, sender_id);

CREATE INDEX IF NOT EXISTS idx_operational_messages_zone 
    ON public.operational_messages (event_id, zone_id);

-- 2. Create public.operational_message_receipts
CREATE TABLE IF NOT EXISTS public.operational_message_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.operational_messages(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'delivered' CHECK (status IN ('delivered', 'read', 'acknowledged')),
    delivered_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    read_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_operational_receipt_message_recipient UNIQUE (message_id, recipient_id)
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_operational_receipts_recipient 
    ON public.operational_message_receipts (recipient_id, status);

CREATE INDEX IF NOT EXISTS idx_operational_receipts_message 
    ON public.operational_message_receipts (message_id);

-- 3. Enable Row Level Security
ALTER TABLE public.operational_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operational_message_receipts ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies: public.operational_messages
-- 4.1 SELECT Policy:
-- Authorized event staff (active volunteer or organizer/admin) can view messages matching target scope:
-- - event-wide: all staff in the event
-- - zone-wide: volunteers assigned to that zone (or roving volunteers with zone_id IS NULL), organizers/admins, or the sender
-- - direct volunteer: sender, recipient, or organizer/admin
-- - organizer: sender, or organizer/admin
DROP POLICY IF EXISTS "Staff can view authorized operational messages" ON public.operational_messages;
CREATE POLICY "Staff can view authorized operational messages"
ON public.operational_messages
FOR SELECT
TO authenticated
USING (
    -- Caller must be associated with the event as active volunteer OR organizer/admin
    (
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid()
              AND va.event_id = operational_messages.event_id
              AND va.status = 'active'
        )
        OR EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.role IN ('organizer', 'admin')
        )
    )
    AND (
        -- Scope A: Event-wide staff broadcast
        target_type = 'event'
        OR
        -- Scope B: Zone-scoped message
        (
            target_type = 'zone'
            AND (
                sender_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM public.volunteer_assignments va
                    WHERE va.volunteer_id = auth.uid()
                      AND va.event_id = operational_messages.event_id
                      AND va.status = 'active'
                      AND (va.zone_id IS NULL OR va.zone_id = operational_messages.zone_id)
                )
                OR EXISTS (
                    SELECT 1 FROM public.profiles p
                    WHERE p.id = auth.uid()
                      AND p.role IN ('organizer', 'admin')
                )
            )
        )
        OR
        -- Scope C: Direct volunteer message
        (
            target_type = 'volunteer'
            AND (
                sender_id = auth.uid()
                OR target_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM public.profiles p
                    WHERE p.id = auth.uid()
                      AND p.role IN ('organizer', 'admin')
                )
            )
        )
        OR
        -- Scope D: Volunteer -> Organizer channel
        (
            target_type = 'organizer'
            AND (
                sender_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM public.profiles p
                    WHERE p.id = auth.uid()
                      AND p.role IN ('organizer', 'admin')
                )
            )
        )
    )
);

-- 4.2 INSERT Policy:
-- Authenticated staff can insert messages if:
-- - sender_id matches auth.uid()
-- - Caller is active volunteer or organizer/admin for the event
-- - Volunteers cannot send event-wide broadcasts (target_type = 'event' reserved for organizers/admins)
DROP POLICY IF EXISTS "Staff can send operational messages" ON public.operational_messages;
CREATE POLICY "Staff can send operational messages"
ON public.operational_messages
FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND (
        -- Organizers and admins can send to any target_type
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.role IN ('organizer', 'admin')
        )
        OR (
            -- Volunteers must have an active assignment to the event
            EXISTS (
                SELECT 1 FROM public.volunteer_assignments va
                WHERE va.volunteer_id = auth.uid()
                  AND va.event_id = operational_messages.event_id
                  AND va.status = 'active'
            )
            -- Volunteers cannot send event-wide broadcasts
            AND target_type IN ('zone', 'volunteer', 'organizer')
        )
    )
);

-- 5. RLS Policies: public.operational_message_receipts
DROP POLICY IF EXISTS "Staff can view relevant message receipts" ON public.operational_message_receipts;
CREATE POLICY "Staff can view relevant message receipts"
ON public.operational_message_receipts
FOR SELECT
TO authenticated
USING (
    recipient_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.operational_messages m
        WHERE m.id = operational_message_receipts.message_id
          AND (
            m.sender_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM public.profiles p
                WHERE p.id = auth.uid()
                  AND p.role IN ('organizer', 'admin')
            )
          )
    )
);

DROP POLICY IF EXISTS "Recipients can manage their own receipts" ON public.operational_message_receipts;
CREATE POLICY "Recipients can manage their own receipts"
ON public.operational_message_receipts
FOR ALL
TO authenticated
USING (
    recipient_id = auth.uid()
)
WITH CHECK (
    recipient_id = auth.uid()
);

-- 6. RPC: Secure Event Volunteer Directory
-- Exposes staff directory strictly within the caller's active event.
-- Hides private profile details (email, phone, metadata, auth credentials).
CREATE OR REPLACE FUNCTION public.get_event_volunteer_directory(
    p_event_id UUID
)
RETURNS TABLE (
    volunteer_id UUID,
    full_name TEXT,
    role TEXT,
    staff_type TEXT,
    zone_id UUID,
    zone_name TEXT,
    zone_code TEXT,
    is_roving BOOLEAN,
    shift_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Verify caller is active volunteer or organizer/admin for the event
    IF NOT (
        EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = auth.uid()
              AND va.event_id = p_event_id
              AND va.status = 'active'
        )
        OR EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.role IN ('organizer', 'admin')
        )
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Caller is not assigned to this event.';
    END IF;

    RETURN QUERY
    SELECT 
        p.id AS volunteer_id,
        p.full_name,
        COALESCE(va.role, 'staff') AS role,
        p.role AS staff_type,
        ez.id AS zone_id,
        ez.name AS zone_name,
        ez.code AS zone_code,
        (va.zone_id IS NULL) AS is_roving,
        va.status AS shift_status
    FROM public.volunteer_assignments va
    JOIN public.profiles p ON p.id = va.volunteer_id
    LEFT JOIN public.event_zones ez ON ez.id = va.zone_id
    WHERE va.event_id = p_event_id
      AND va.status = 'active'
    ORDER BY p.full_name ASC;
END;
$$;

-- 7. RPC: Send Operational Message
CREATE OR REPLACE FUNCTION public.send_operational_message(
    p_event_id UUID,
    p_target_type TEXT,
    p_body TEXT,
    p_target_id UUID DEFAULT NULL,
    p_zone_id UUID DEFAULT NULL,
    p_message_type TEXT DEFAULT 'operational',
    p_priority TEXT DEFAULT 'normal',
    p_requires_acknowledgment BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_name TEXT;
    v_is_staff BOOLEAN;
    v_new_msg_id UUID;
    v_trimmed_body TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED', 'message', 'Caller is not authenticated.');
    END IF;

    -- Fetch caller profile
    SELECT role, full_name INTO v_caller_role, v_caller_name
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'NO_PROFILE', 'message', 'Profile not found.');
    END IF;

    -- Verify event authorization
    IF v_caller_role IN ('organizer', 'admin') THEN
        v_is_staff := true;
    ELSE
        SELECT EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = v_caller_id
              AND va.event_id = p_event_id
              AND va.status = 'active'
        ) INTO v_is_staff;
    END IF;

    IF NOT v_is_staff THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_EVENT', 'message', 'Caller does not have an active shift for this event.');
    END IF;

    -- Validate target_type restrictions
    IF p_target_type = 'event' AND v_caller_role NOT IN ('organizer', 'admin') THEN
        RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN_BROADCAST', 'message', 'Only organizers and admins can send event-wide broadcasts.');
    END IF;

    -- Validate target recipient if target_type is volunteer
    IF p_target_type = 'volunteer' THEN
        IF p_target_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'MISSING_RECIPIENT', 'message', 'Target recipient ID is required for direct messages.');
        END IF;

        -- Ensure recipient is part of the same event
        IF NOT EXISTS (
            SELECT 1 FROM public.volunteer_assignments va
            WHERE va.volunteer_id = p_target_id
              AND va.event_id = p_event_id
              AND va.status = 'active'
        ) AND NOT EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = p_target_id AND p.role IN ('organizer', 'admin')
        ) THEN
            RETURN jsonb_build_object('success', false, 'error', 'RECIPIENT_NOT_IN_EVENT', 'message', 'Recipient is not assigned to this event.');
        END IF;
    END IF;

    -- Validate body length
    v_trimmed_body := trim(p_body);
    IF char_length(v_trimmed_body) = 0 OR char_length(v_trimmed_body) > 1000 THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_BODY_LENGTH', 'message', 'Message body must be between 1 and 1000 characters.');
    END IF;

    -- Insert message
    INSERT INTO public.operational_messages (
        event_id,
        sender_id,
        sender_role,
        sender_name,
        target_type,
        target_id,
        zone_id,
        message_type,
        priority,
        body,
        requires_acknowledgment
    ) VALUES (
        p_event_id,
        v_caller_id,
        v_caller_role,
        COALESCE(v_caller_name, 'Staff'),
        p_target_type,
        p_target_id,
        p_zone_id,
        COALESCE(p_message_type, 'operational'),
        COALESCE(p_priority, 'normal'),
        v_trimmed_body,
        COALESCE(p_requires_acknowledgment, false)
    ) RETURNING id INTO v_new_msg_id;

    RETURN jsonb_build_object(
        'success', true,
        'message_id', v_new_msg_id,
        'event_id', p_event_id,
        'sender_id', v_caller_id,
        'sender_name', v_caller_name,
        'sender_role', v_caller_role,
        'target_type', p_target_type,
        'created_at', now()
    );
END;
$$;

-- 8. RPC: Acknowledge Operational Message
CREATE OR REPLACE FUNCTION public.acknowledge_operational_message(
    p_message_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_msg RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED');
    END IF;

    -- Fetch message
    SELECT * INTO v_msg
    FROM public.operational_messages
    WHERE id = p_message_id;

    IF v_msg.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Message not found.');
    END IF;

    -- Upsert receipt as acknowledged
    INSERT INTO public.operational_message_receipts (
        message_id,
        recipient_id,
        status,
        delivered_at,
        read_at,
        acknowledged_at
    ) VALUES (
        p_message_id,
        v_caller_id,
        'acknowledged',
        v_now,
        v_now,
        v_now
    )
    ON CONFLICT (message_id, recipient_id)
    DO UPDATE SET
        status = 'acknowledged',
        read_at = COALESCE(operational_message_receipts.read_at, v_now),
        acknowledged_at = v_now;

    RETURN jsonb_build_object(
        'success', true,
        'message_id', p_message_id,
        'status', 'acknowledged',
        'acknowledged_at', v_now
    );
END;
$$;

-- 9. RPC: Batch Mark Messages as Read
CREATE OR REPLACE FUNCTION public.mark_operational_messages_read(
    p_message_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_msg_id UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_count INT := 0;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED');
    END IF;

    FOREACH v_msg_id IN ARRAY p_message_ids LOOP
        INSERT INTO public.operational_message_receipts (
            message_id,
            recipient_id,
            status,
            delivered_at,
            read_at
        ) VALUES (
            v_msg_id,
            v_caller_id,
            'read',
            v_now,
            v_now
        )
        ON CONFLICT (message_id, recipient_id)
        DO UPDATE SET
            status = CASE 
                WHEN operational_message_receipts.status = 'acknowledged' THEN 'acknowledged'
                ELSE 'read'
            END,
            read_at = COALESCE(operational_message_receipts.read_at, v_now);
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'marked_count', v_count);
END;
$$;

-- 10. Enable Supabase Realtime for operational communication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'operational_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.operational_messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'operational_message_receipts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.operational_message_receipts;
    END IF;
END $$;
