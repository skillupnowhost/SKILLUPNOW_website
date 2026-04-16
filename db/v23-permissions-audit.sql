-- v23: Permissions Audit — missing GRANTs + RLS policy fixes for mentor & admin roles
-- Root causes:
--   A. "permission denied for table student_profiles" — the table-level GRANT was completely
--      absent from admin-dashboard-grants.sql.  PostgreSQL checks GRANTs BEFORE evaluating
--      RLS policies, so the query is rejected outright even if an RLS policy would allow it.
--   B. "permission denied for table class_attendance" — same cause.
--   C. user_profiles SELECT policy only covers is_admin() (user_role_assignments); mentors
--      stored in mentor_profiles are therefore blocked on the PostgREST join chain:
--        enrollments → student_profiles → user_profiles!student_profiles_user_id_fkey
--   D. student_profiles RLS policy (v22 §9) must be idempotently re-applied for fresh deploys.
-- Run in Supabase SQL Editor.  Safe to re-run; all statements are idempotent.

-- ══ SECTION 1: Table-level GRANTs ════════════════════════════════════════════════════════════
--    These are the "outer gate". Without them Postgres says "permission denied for table X"
--    before RLS policies are ever evaluated.

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.student_profiles  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.class_attendance   TO authenticated;

-- Ensure previously-added grants are also present (idempotent)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.enrollments        TO authenticated;
GRANT SELECT                          ON TABLE public.user_profiles      TO authenticated;
GRANT SELECT                          ON TABLE public.mentor_profiles    TO authenticated;
GRANT SELECT                          ON TABLE public.admin_profiles     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE  ON TABLE public.course_batches     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE  ON TABLE public.class_sessions     TO authenticated;

-- ══ SECTION 1b: anon GRANTs for public pages (pamphlet, landing) ══════════════════════════
--    Public pages use the anon key — GRANTs to 'authenticated' do NOT cover them.
--    Required for: pamphlet "Meet Our Mentors" section, course cards mentor strip.
GRANT SELECT ON TABLE public.mentor_profiles  TO anon;
GRANT SELECT ON TABLE public.user_profiles    TO anon;
GRANT SELECT ON TABLE public.course_batches   TO anon;
GRANT SELECT ON TABLE public.courses          TO anon;
GRANT SELECT ON TABLE public.course_categories TO anon;

-- ══ SECTION 2: RLS — user_profiles SELECT ════════════════════════════════════════════════════
--    Extend the existing policy to cover admin_profiles users and approved mentors.
--    Required for: enrollments → student_profiles → user_profiles join in both dashboards.
DROP POLICY IF EXISTS user_profiles_self_or_admin_select ON public.user_profiles;
CREATE POLICY user_profiles_self_or_admin_select ON public.user_profiles
  FOR SELECT
  USING (
    -- Own profile
    user_id = auth.uid()
    -- Admin roles
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    -- Approved mentors can read other profiles
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
    -- Anyone can read an approved mentor's profile (needed for student "My Mentor" page
    -- and for the public pamphlet join: course_batches → mentor_profiles → user_profiles)
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = user_profiles.user_id AND mp.status = 'approved'
    )
  );

-- ══ SECTION 3: RLS — student_profiles ════════════════════════════════════════════════════════
--    Idempotent re-apply of v22 §9 so fresh deployments are always consistent.
DROP POLICY IF EXISTS student_profiles_self_or_admin ON public.student_profiles;
CREATE POLICY student_profiles_self_or_admin ON public.student_profiles
  FOR ALL
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
  );

-- ══ SECTION 4: RLS — class_attendance ════════════════════════════════════════════════════════
--    Mentors must be able to INSERT/UPDATE/SELECT attendance rows for their own batches.
--    Admins need full access.
DO $$
BEGIN
  -- Enable RLS if not already on (safe to call even if already enabled)
  ALTER TABLE public.class_attendance ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL;
END$$;

DROP POLICY IF EXISTS class_attendance_mentor_admin ON public.class_attendance;
CREATE POLICY class_attendance_mentor_admin ON public.class_attendance
  FOR ALL
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.class_sessions cs
      JOIN public.course_batches cb ON cb.id = cs.batch_id
      WHERE cs.id = class_attendance.class_session_id
        AND cb.primary_mentor_user_id = auth.uid()
    )
    OR student_user_id = auth.uid()
  )
  WITH CHECK (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.class_sessions cs
      JOIN public.course_batches cb ON cb.id = cs.batch_id
      WHERE cs.id = class_attendance.class_session_id
        AND cb.primary_mentor_user_id = auth.uid()
    )
  );

-- ══ SECTION 5: Diagnostic ════════════════════════════════════════════════════════════════════
--    Run this SELECT after applying v23 to confirm all policies are in place.
SELECT
  tablename,
  policyname,
  cmd,
  LEFT(qual::text, 120) AS using_clause
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'user_profiles', 'student_profiles', 'enrollments',
    'mentor_profiles', 'class_attendance'
  )
ORDER BY tablename, policyname;
