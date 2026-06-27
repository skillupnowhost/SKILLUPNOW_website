-- ============================================================
-- v43 — Fix Generated Columns + Enhanced App Tracking
-- Fixes: total_work_mins GENERATED ALWAYS error on endWork()
-- Adds: total_break_mins, net_work_mins, break_type, ip_address
-- Removes dependency on GENERATED ALWAYS columns so JS can
-- set values directly.
-- Run AFTER v42-unlimited-breaks.sql
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- PART 1: Fix intern_work_sessions — drop GENERATED columns
-- ════════════════════════════════════════════════════════════

-- Drop the generated total_work_mins column and recreate as regular
ALTER TABLE public.intern_work_sessions DROP COLUMN IF EXISTS total_work_mins;
ALTER TABLE public.intern_work_sessions ADD COLUMN total_work_mins int DEFAULT 0;

-- Add missing columns for break/net tracking
ALTER TABLE public.intern_work_sessions ADD COLUMN IF NOT EXISTS total_break_mins int DEFAULT 0;
ALTER TABLE public.intern_work_sessions ADD COLUMN IF NOT EXISTS net_work_mins int DEFAULT 0;

-- Add IP address tracking
ALTER TABLE public.intern_work_sessions ADD COLUMN IF NOT EXISTS ip_address text;

-- Backfill total_work_mins for any completed sessions
UPDATE public.intern_work_sessions SET
  total_work_mins = CASE
    WHEN start_time IS NOT NULL AND end_time IS NOT NULL
    THEN GREATEST(0, EXTRACT(EPOCH FROM (end_time - start_time))::int / 60)
    ELSE 0
  END
WHERE end_time IS NOT NULL AND (total_work_mins IS NULL OR total_work_mins = 0);


-- ════════════════════════════════════════════════════════════
-- PART 2: Fix intern_breaks — drop GENERATED duration_mins
-- ════════════════════════════════════════════════════════════

-- Drop the generated duration_mins and recreate as regular
ALTER TABLE public.intern_breaks DROP COLUMN IF EXISTS duration_mins;
ALTER TABLE public.intern_breaks ADD COLUMN duration_mins int DEFAULT 0;

-- Add break_type column
ALTER TABLE public.intern_breaks ADD COLUMN IF NOT EXISTS break_type text DEFAULT 'general';

-- Backfill duration_mins for completed breaks
UPDATE public.intern_breaks SET
  duration_mins = CASE
    WHEN break_start IS NOT NULL AND break_end IS NOT NULL
    THEN GREATEST(0, EXTRACT(EPOCH FROM (break_end - break_start))::int / 60)
    ELSE 0
  END
WHERE break_end IS NOT NULL AND (duration_mins IS NULL OR duration_mins = 0);


-- ════════════════════════════════════════════════════════════
-- PART 3: Enhance intern_app_usage with IP + network data
-- ════════════════════════════════════════════════════════════

ALTER TABLE public.intern_app_usage ADD COLUMN IF NOT EXISTS ip_address text;
ALTER TABLE public.intern_app_usage ADD COLUMN IF NOT EXISTS category text DEFAULT 'general';
ALTER TABLE public.intern_app_usage ADD COLUMN IF NOT EXISTS is_hidden boolean DEFAULT false;


-- ════════════════════════════════════════════════════════════
-- PART 4: Admin tracking removal log
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.intern_tracking_removals (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid REFERENCES public.intern_work_sessions(id) ON DELETE SET NULL,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  removed_by       uuid NOT NULL REFERENCES auth.users(id),
  removal_type     text NOT NULL CHECK (removal_type IN ('app_usage','session','break','all_day')),
  records_removed  int DEFAULT 0,
  reason           text,
  removed_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.intern_tracking_removals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tr_admin_only" ON public.intern_tracking_removals
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, INSERT ON public.intern_tracking_removals TO authenticated;
GRANT ALL ON public.intern_tracking_removals TO service_role;

CREATE INDEX IF NOT EXISTS idx_tr_student ON public.intern_tracking_removals(student_user_id);
CREATE INDEX IF NOT EXISTS idx_tr_session ON public.intern_tracking_removals(session_id);


-- ════════════════════════════════════════════════════════════
-- PART 5: Admin RPC to bulk-delete tracking data
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.admin_remove_tracking(
  p_session_id uuid,
  p_removal_type text DEFAULT 'app_usage',
  p_reason text DEFAULT ''
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count int := 0;
  v_student_id uuid;
BEGIN
  IF NOT public._is_intern_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT student_user_id INTO v_student_id
  FROM public.intern_work_sessions WHERE id = p_session_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;

  IF p_removal_type = 'app_usage' THEN
    DELETE FROM public.intern_app_usage WHERE session_id = p_session_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_removal_type = 'all_day' THEN
    DELETE FROM public.intern_app_usage WHERE session_id = p_session_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    DELETE FROM public.intern_breaks WHERE session_id = p_session_id;
  END IF;

  INSERT INTO public.intern_tracking_removals
    (session_id, student_user_id, removed_by, removal_type, records_removed, reason)
  VALUES
    (p_session_id, v_student_id, auth.uid(), p_removal_type, v_count, p_reason);

  RETURN jsonb_build_object('removed', v_count, 'type', p_removal_type);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_remove_tracking TO authenticated;
