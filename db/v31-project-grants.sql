-- ============================================================
-- SKILLUPNOW — PROJECT MODULE GRANTS + RLS FIXES
-- v31: Grants table-level permissions for all project tables.
--      Run AFTER v30-project-module.sql and internship-rls-fix.sql.
-- ============================================================

-- ── Schema usage ──────────────────────────────────────────────
GRANT USAGE ON SCHEMA public TO authenticated, anon;

-- ── New project tables → authenticated (RLS still applies) ────
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.project_modules       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.project_assignments   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.project_work_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.project_activity_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.project_git_repos     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.project_git_access    TO authenticated;

-- ── Public read for project_modules (anonymous visitors) ──────
GRANT SELECT ON TABLE public.project_modules   TO anon;
GRANT SELECT ON TABLE public.internship_projects TO anon;

-- ── Internship tables (in case not granted yet) ───────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internship_projects     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internship_enrollments  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internship_daily_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internship_attendance   TO authenticated;

-- ── Sequences ─────────────────────────────────────────────────
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================
-- FIX RLS POLICIES: Add WITH CHECK to all admin FOR ALL policies
-- (FOR ALL without WITH CHECK can block INSERTs for admins)
-- ============================================================

-- project_modules
DROP POLICY IF EXISTS "pm_admin_all"   ON public.project_modules;
DROP POLICY IF EXISTS "pm_read_active" ON public.project_modules;
CREATE POLICY "pm_read_active" ON public.project_modules
  FOR SELECT USING (is_active = true OR public._is_intern_admin());
CREATE POLICY "pm_admin_all" ON public.project_modules
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

-- project_assignments
DROP POLICY IF EXISTS "pa_admin_all"      ON public.project_assignments;
DROP POLICY IF EXISTS "pa_student_select" ON public.project_assignments;
CREATE POLICY "pa_student_select" ON public.project_assignments
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pa_admin_all" ON public.project_assignments
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

-- project_work_sessions
DROP POLICY IF EXISTS "pws_admin_all"      ON public.project_work_sessions;
DROP POLICY IF EXISTS "pws_student_select" ON public.project_work_sessions;
DROP POLICY IF EXISTS "pws_student_insert" ON public.project_work_sessions;
DROP POLICY IF EXISTS "pws_student_update" ON public.project_work_sessions;
CREATE POLICY "pws_student_select" ON public.project_work_sessions
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pws_student_insert" ON public.project_work_sessions
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "pws_student_update" ON public.project_work_sessions
  FOR UPDATE USING (student_user_id = auth.uid() AND is_active = true);
CREATE POLICY "pws_admin_all" ON public.project_work_sessions
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

-- project_activity_logs
DROP POLICY IF EXISTS "pal_admin_all"      ON public.project_activity_logs;
DROP POLICY IF EXISTS "pal_student_select" ON public.project_activity_logs;
DROP POLICY IF EXISTS "pal_student_insert" ON public.project_activity_logs;
CREATE POLICY "pal_student_select" ON public.project_activity_logs
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pal_student_insert" ON public.project_activity_logs
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "pal_admin_all" ON public.project_activity_logs
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

-- project_git_repos
DROP POLICY IF EXISTS "pgr_admin_all"       ON public.project_git_repos;
DROP POLICY IF EXISTS "pgr_assigned_select" ON public.project_git_repos;
CREATE POLICY "pgr_assigned_select" ON public.project_git_repos
  FOR SELECT USING (
    public._is_intern_admin() OR
    EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.project_id = project_git_repos.project_id
        AND pa.student_user_id = auth.uid()
        AND pa.status = 'active'
    )
  );
CREATE POLICY "pgr_admin_all" ON public.project_git_repos
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

-- project_git_access
DROP POLICY IF EXISTS "pga_admin_all"      ON public.project_git_access;
DROP POLICY IF EXISTS "pga_student_select" ON public.project_git_access;
CREATE POLICY "pga_student_select" ON public.project_git_access
  FOR SELECT USING (
    public._is_intern_admin() OR
    EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.id = project_git_access.assignment_id
        AND pa.student_user_id = auth.uid()
    )
  );
CREATE POLICY "pga_admin_all" ON public.project_git_access
  FOR ALL USING (public._is_intern_admin()) WITH CHECK (public._is_intern_admin());

-- ============================================================
-- VERIFY — run after applying:
--
--   SELECT public._is_intern_admin();
--   → should return TRUE when logged in as admin
--
--   SELECT has_table_privilege('authenticated','public.project_modules','SELECT');
--   → should return TRUE
-- ============================================================
