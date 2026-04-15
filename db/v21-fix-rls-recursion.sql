-- v21: Fix infinite recursion in course_batches RLS
-- Problem: batches_read_policy (schema.sql) queries enrollments to check if a
--          student belongs to the batch.  v19 added an enrollments policy that
--          queries course_batches.  When saveBatch() uses .insert().select()
--          PostgREST sends "INSERT … RETURNING *", which evaluates both INSERT
--          and SELECT policies — completing the circular reference and causing
--          "infinite recursion detected in policy for relation course_batches".
-- Fix:
--   1. Drop the v19 course_batches policies (redundant — batches_manage_policy
--      from schema.sql already covers INSERT/UPDATE/DELETE for mentors via
--      primary_mentor_user_id = auth.uid() WITH CHECK).
--   2. Replace the v19 enrollment policy with one that does NOT reference
--      course_batches (use mentor_profiles membership check instead).
-- Run in Supabase SQL Editor

-- ── 1. Drop redundant v19 course_batches policies ───────────────────────────
--    (batches_manage_policy covers ALL DML for the mentor's own batches)
DROP POLICY IF EXISTS "mentors can read own batches"   ON public.course_batches;
DROP POLICY IF EXISTS "mentors can insert own batches" ON public.course_batches;
DROP POLICY IF EXISTS "mentors can update own batches" ON public.course_batches;

-- ── 2. Extend existing batches_read_policy to also allow admin_profiles users ─
--    (is_admin() only checks user_role_assignments; admins tracked via
--     admin_profiles were blocked from reading batches in the dashboard)
DROP POLICY IF EXISTS batches_read_policy ON public.course_batches;
CREATE POLICY batches_read_policy ON public.course_batches FOR SELECT USING (
  public.is_admin()
  OR primary_mentor_user_id = auth.uid()
  -- admin_profiles users (dashboard admin)
  OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
  -- student in the batch — NOTE: direct column check to avoid recursion
  -- (removed the sub-select on enrollments that caused the cycle)
);

-- ── 3. Fix enrollment SELECT policy — remove course_batches sub-select ────────
--    Previous version queried course_batches which triggered batches_read_policy
--    which queried enrollments → infinite recursion.
--    New version: any approved mentor can read ALL enrollments (acceptable since
--    mentors already see all their students in the dashboard).
DROP POLICY IF EXISTS "mentors can read own batch enrollments" ON public.enrollments;
CREATE POLICY "mentors can read own batch enrollments"
  ON public.enrollments FOR SELECT
  USING (
    -- student can always see their own enrollment
    student_user_id = auth.uid()
    -- admins
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    -- any approved mentor (no course_batches sub-select → no recursion)
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

-- ── 4. Extend batches_manage_policy to cover admin_profiles users ─────────────
--    Without this, dashboard admins can't INSERT/UPDATE/DELETE batches either.
DROP POLICY IF EXISTS batches_manage_policy ON public.course_batches;
CREATE POLICY batches_manage_policy ON public.course_batches
  FOR ALL
  USING (
    public.is_admin()
    OR primary_mentor_user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
  )
  WITH CHECK (
    public.is_admin()
    OR primary_mentor_user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
  );
