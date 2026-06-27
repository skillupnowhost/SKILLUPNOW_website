-- ============================================================
-- v45 — Network Tracking + Enhanced Bulk Delete
-- Adds: network_info column to intern_work_sessions
-- Enhances: admin_remove_tracking RPC to handle break deletion
-- Run AFTER v44-fix-delete-user.sql
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- PART 1: Add network_info column to work sessions
-- ════════════════════════════════════════════════════════════

ALTER TABLE public.intern_work_sessions
  ADD COLUMN IF NOT EXISTS network_info text;

COMMENT ON COLUMN public.intern_work_sessions.network_info IS
  'Network details captured at session start: IP, connection type, speed, ISP, location';


-- ════════════════════════════════════════════════════════════
-- PART 2: Update admin_remove_tracking to support break removal
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

  ELSIF p_removal_type = 'break' THEN
    DELETE FROM public.intern_breaks WHERE session_id = p_session_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;

  ELSIF p_removal_type = 'all_day' THEN
    DELETE FROM public.intern_app_usage WHERE session_id = p_session_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    DELETE FROM public.intern_breaks WHERE session_id = p_session_id;
    v_count := v_count + (SELECT count(*) FROM (SELECT 1) AS dummy);

  END IF;

  INSERT INTO public.intern_tracking_removals
    (session_id, student_user_id, removed_by, removal_type, records_removed, reason)
  VALUES
    (p_session_id, v_student_id, auth.uid(), p_removal_type, v_count, p_reason);

  RETURN jsonb_build_object('removed', v_count, 'type', p_removal_type);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_remove_tracking TO authenticated;
