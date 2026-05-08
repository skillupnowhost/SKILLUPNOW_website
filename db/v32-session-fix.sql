-- ============================================================
-- SKILLUPNOW — SESSION RLS FIX + SECURITY ALERTS
-- v32: Fixes project_work_sessions UPDATE policy that was
--      blocking session_end updates (trigger sets is_active=false
--      which failed the implicit WITH CHECK).
--      Adds end_work_session() RPC + security_alerts table.
-- Run AFTER v31-project-grants.sql
-- ============================================================

-- ── Fix UPDATE policy: allow new row to have is_active=false ──
DROP POLICY IF EXISTS "pws_student_update" ON public.project_work_sessions;
CREATE POLICY "pws_student_update" ON public.project_work_sessions
  FOR UPDATE
  USING  (student_user_id = auth.uid() AND is_active = true)
  WITH CHECK (student_user_id = auth.uid());

-- ── SECURITY DEFINER RPC — safe session-end bypassing RLS ────
CREATE OR REPLACE FUNCTION public.end_work_session(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM project_work_sessions
    WHERE id = p_session_id
      AND student_user_id = auth.uid()
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Session not found or not authorized';
  END IF;
  UPDATE project_work_sessions
    SET session_end = NOW()
    WHERE id = p_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.end_work_session(UUID) TO authenticated;

-- ── Security Alerts table ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_alerts (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assignment_id    UUID REFERENCES public.project_assignments(id) ON DELETE SET NULL,
  session_id       UUID REFERENCES public.project_work_sessions(id) ON DELETE SET NULL,
  alert_type       TEXT NOT NULL,
  details          JSONB DEFAULT '{}'::jsonb,
  is_read          BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "secalert_admin_all"       ON public.security_alerts;
DROP POLICY IF EXISTS "secalert_student_insert"  ON public.security_alerts;

CREATE POLICY "secalert_admin_all" ON public.security_alerts
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

CREATE POLICY "secalert_student_insert" ON public.security_alerts
  FOR INSERT WITH CHECK (student_user_id = auth.uid());

GRANT SELECT, INSERT ON TABLE public.security_alerts TO authenticated;

CREATE INDEX IF NOT EXISTS idx_secalert_student  ON public.security_alerts(student_user_id);
CREATE INDEX IF NOT EXISTS idx_secalert_unread   ON public.security_alerts(is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_secalert_type     ON public.security_alerts(alert_type);

-- ============================================================
-- VERIFY:
--   SELECT public.end_work_session('<session-uuid>');  -- as student
--   SELECT * FROM public.security_alerts;              -- as admin
-- ============================================================
