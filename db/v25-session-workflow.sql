-- v25-session-workflow.sql
-- Adds auto-generated Jitsi links, recording linkage, and 12-session progress automation.

ALTER TABLE public.class_sessions
  ADD COLUMN IF NOT EXISTS session_number INT,
  ADD COLUMN IF NOT EXISTS meeting_provider TEXT NOT NULL DEFAULT 'jitsi'
    CHECK (meeting_provider IN ('jitsi', 'google_meet', 'zoom', 'other')),
  ADD COLUMN IF NOT EXISTS meeting_room_name TEXT,
  ADD COLUMN IF NOT EXISTS meeting_notes JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS meeting_recording_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS recording_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (recording_status IN ('pending', 'recording', 'ready', 'failed')),
  ADD COLUMN IF NOT EXISTS recording_external_url TEXT,
  ADD COLUMN IF NOT EXISTS recording_synced_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (notification_status IN ('pending', 'sent', 'failed', 'cancelled')),
  ADD COLUMN IF NOT EXISTS last_notified_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS idx_class_sessions_batch_session_number
  ON public.class_sessions (batch_id, session_number)
  WHERE session_number IS NOT NULL;

CREATE OR REPLACE FUNCTION public.slugify_text(input TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT trim(both '-' FROM regexp_replace(lower(coalesce(input, '')), '[^a-z0-9]+', '-', 'g'));
$$;

CREATE OR REPLACE FUNCTION public.apply_class_session_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch_code TEXT;
  v_seq INT;
  v_room TEXT;
BEGIN
  IF NEW.session_number IS NULL THEN
    SELECT COALESCE(MAX(cs.session_number), 0) + 1
      INTO v_seq
      FROM public.class_sessions cs
     WHERE cs.batch_id = NEW.batch_id
       AND (TG_OP = 'INSERT' OR cs.id <> NEW.id);
    NEW.session_number := GREATEST(v_seq, 1);
  END IF;

  IF NEW.meeting_provider = 'jitsi' THEN
    SELECT cb.batch_code
      INTO v_batch_code
      FROM public.course_batches cb
     WHERE cb.id = NEW.batch_id;

    v_room := left(
      concat_ws(
        '-',
        'skillupnow',
        public.slugify_text(v_batch_code),
        's' || NEW.session_number::TEXT,
        public.slugify_text(NEW.session_title),
        to_char(NEW.scheduled_start_at AT TIME ZONE 'UTC', 'YYYYMMDD')
      ),
      96
    );

    NEW.meeting_room_name := coalesce(nullif(NEW.meeting_room_name, ''), v_room);
    IF coalesce(nullif(NEW.meeting_url, ''), '') = '' THEN
      NEW.meeting_url := 'https://meet.jit.si/' || NEW.meeting_room_name;
    END IF;
  END IF;

  IF coalesce(nullif(NEW.recording_external_url, ''), '') <> '' THEN
    NEW.recording_status := 'ready';
    NEW.recording_synced_at := NOW();
  ELSIF NEW.session_status = 'completed' AND NEW.recording_status = 'pending' THEN
    NEW.recording_status := 'recording';
  END IF;

  IF NEW.session_status = 'cancelled' THEN
    NEW.notification_status := 'cancelled';
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_class_session_defaults ON public.class_sessions;
CREATE TRIGGER trg_apply_class_session_defaults
BEFORE INSERT OR UPDATE ON public.class_sessions
FOR EACH ROW
EXECUTE FUNCTION public.apply_class_session_defaults();

CREATE OR REPLACE FUNCTION public.sync_session_recording_to_library()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF coalesce(nullif(NEW.recording_external_url, ''), '') = '' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.live_recordings (
    course_id,
    batch_id,
    class_session_id,
    title,
    provider_name,
    external_url,
    access_level,
    is_published,
    published_at,
    updated_at
  )
  VALUES (
    NEW.course_id,
    NEW.batch_id,
    NEW.id,
    NEW.session_title,
    'other',
    NEW.recording_external_url,
    'paid',
    TRUE,
    coalesce(NEW.recording_synced_at, NOW()),
    NOW()
  )
  ON CONFLICT (class_session_id) DO UPDATE
    SET title = EXCLUDED.title,
        external_url = EXCLUDED.external_url,
        batch_id = EXCLUDED.batch_id,
        course_id = EXCLUDED.course_id,
        is_published = TRUE,
        updated_at = NOW();

  RETURN NEW;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_live_recordings_class_session
  ON public.live_recordings (class_session_id)
  WHERE class_session_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_sync_session_recording_to_library ON public.class_sessions;
CREATE TRIGGER trg_sync_session_recording_to_library
AFTER INSERT OR UPDATE OF recording_external_url, recording_status, session_title, course_id, batch_id
ON public.class_sessions
FOR EACH ROW
EXECUTE FUNCTION public.sync_session_recording_to_library();

CREATE OR REPLACE FUNCTION public.refresh_session_progress_from_attendance(p_class_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch_id UUID;
BEGIN
  SELECT batch_id
    INTO v_batch_id
    FROM public.class_sessions
   WHERE id = p_class_session_id;

  IF v_batch_id IS NULL THEN
    RETURN;
  END IF;

  WITH attendance_totals AS (
    SELECT
      ca.student_user_id,
      COUNT(*) FILTER (
        WHERE ca.attendance_status IN ('present', 'late')
      ) AS attended_sessions
    FROM public.class_attendance ca
    JOIN public.class_sessions cs
      ON cs.id = ca.class_session_id
    WHERE cs.batch_id = v_batch_id
      AND cs.session_status = 'completed'
    GROUP BY ca.student_user_id
  )
  UPDATE public.enrollments e
     SET progress_percentage = LEAST(100, ROUND((coalesce(a.attended_sessions, 0)::NUMERIC / 12::NUMERIC) * 100, 2)),
         enrollment_status = CASE
           WHEN coalesce(a.attended_sessions, 0) >= 12 THEN 'completed'::public.enrollment_status
           ELSE e.enrollment_status
         END,
         completed_at = CASE
           WHEN coalesce(a.attended_sessions, 0) >= 12 AND e.completed_at IS NULL THEN NOW()
           ELSE e.completed_at
         END,
         updated_at = NOW()
    FROM attendance_totals a
   WHERE e.batch_id = v_batch_id
     AND e.student_user_id = a.student_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_attendance_progress_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.refresh_session_progress_from_attendance(coalesce(NEW.class_session_id, OLD.class_session_id));
  RETURN coalesce(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_attendance_progress_refresh ON public.class_attendance;
CREATE TRIGGER trg_attendance_progress_refresh
AFTER INSERT OR UPDATE OR DELETE ON public.class_attendance
FOR EACH ROW
EXECUTE FUNCTION public.handle_attendance_progress_refresh();
