-- ============================================================
-- INTERNSHIP MODULE — RLS FIX (v3)
-- Run in Supabase SQL Editor → SQL Editor tab.
-- Uses the same tables that checkAdminAuth() uses:
--   • user_role_assignments (role, is_active)
--   • admin_profiles        (status)
-- ============================================================

-- Upgrade function in-place (SECURITY DEFINER bypasses RLS on helper tables)
CREATE OR REPLACE FUNCTION public._is_intern_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    -- Primary check: user_role_assignments (same as checkAdminAuth)
    EXISTS (
      SELECT 1 FROM public.user_role_assignments
      WHERE user_id    = auth.uid()
        AND role       IN ('admin', 'super_admin', 'support')
        AND is_active  = true
    )
    OR
    -- Fallback: admin_profiles with active status
    EXISTS (
      SELECT 1 FROM public.admin_profiles
      WHERE user_id = auth.uid()
        AND status  = 'active'
    )
    OR
    -- Fallback 2: user_profiles role column
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_id = auth.uid()
        AND role IN ('admin', 'super_admin')
    );
$$;

GRANT EXECUTE ON FUNCTION public._is_intern_admin() TO authenticated, anon;

-- ============================================================
-- Re-apply policies (no change to logic, just ensures they are fresh)
-- ============================================================

-- internship_projects
DROP POLICY IF EXISTS "ip_read_active" ON public.internship_projects;
DROP POLICY IF EXISTS "ip_admin_all"   ON public.internship_projects;

CREATE POLICY "ip_read_active" ON public.internship_projects
  FOR SELECT USING (is_active = true OR public._is_intern_admin());

CREATE POLICY "ip_admin_all" ON public.internship_projects
  FOR ALL
  USING     (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- internship_enrollments
DROP POLICY IF EXISTS "ie_student_select" ON public.internship_enrollments;
DROP POLICY IF EXISTS "ie_student_insert" ON public.internship_enrollments;
DROP POLICY IF EXISTS "ie_admin_all"      ON public.internship_enrollments;

CREATE POLICY "ie_student_select" ON public.internship_enrollments
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());

CREATE POLICY "ie_student_insert" ON public.internship_enrollments
  FOR INSERT WITH CHECK (student_user_id = auth.uid());

CREATE POLICY "ie_admin_all" ON public.internship_enrollments
  FOR ALL
  USING     (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- internship_daily_reports
DROP POLICY IF EXISTS "idr_student_select" ON public.internship_daily_reports;
DROP POLICY IF EXISTS "idr_student_insert" ON public.internship_daily_reports;
DROP POLICY IF EXISTS "idr_student_update" ON public.internship_daily_reports;
DROP POLICY IF EXISTS "idr_admin_all"      ON public.internship_daily_reports;

CREATE POLICY "idr_student_select" ON public.internship_daily_reports
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());

CREATE POLICY "idr_student_insert" ON public.internship_daily_reports
  FOR INSERT WITH CHECK (student_user_id = auth.uid());

CREATE POLICY "idr_student_update" ON public.internship_daily_reports
  FOR UPDATE USING (student_user_id = auth.uid() AND report_status = 'submitted');

CREATE POLICY "idr_admin_all" ON public.internship_daily_reports
  FOR ALL
  USING     (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- internship_attendance
DROP POLICY IF EXISTS "ia_student_select" ON public.internship_attendance;
DROP POLICY IF EXISTS "ia_admin_all"      ON public.internship_attendance;

CREATE POLICY "ia_student_select" ON public.internship_attendance
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());

CREATE POLICY "ia_admin_all" ON public.internship_attendance
  FOR ALL
  USING     (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ============================================================
-- VERIFY — run these after applying to confirm it works:
--
--   SELECT public._is_intern_admin();
--   --> should return TRUE when logged in as admin
--
-- If it still returns FALSE, check your admin record exists:
--   SELECT user_id, role, is_active FROM public.user_role_assignments
--   WHERE user_id = auth.uid();
-- ============================================================
