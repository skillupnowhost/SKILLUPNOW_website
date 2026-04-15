-- v19: Allow mentors to search user/student profiles for batch enrolment
-- Run in Supabase SQL Editor

-- ── 1. Allow approved mentors to SELECT any user_profiles row ────────────────
--    (needed so mentor dashboard "Add Students" search works)
DROP POLICY IF EXISTS "mentors can search user profiles" ON public.user_profiles;
CREATE POLICY "mentors can search user profiles"
  ON public.user_profiles FOR SELECT
  USING (
    -- own profile (always visible)
    user_id = auth.uid()
    OR
    -- any admin
    EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR
    -- approved mentor searching students
    EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

-- ── 2. Allow approved mentors to SELECT student_profiles ────────────────────
DROP POLICY IF EXISTS "mentors can read student profiles" ON public.student_profiles;
CREATE POLICY "mentors can read student profiles"
  ON public.student_profiles FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

-- ── 3. Allow mentors to read + write their own course_batches ───────────────
DROP POLICY IF EXISTS "mentors can read own batches" ON public.course_batches;
CREATE POLICY "mentors can read own batches"
  ON public.course_batches FOR SELECT
  USING (
    primary_mentor_user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "mentors can insert own batches" ON public.course_batches;
CREATE POLICY "mentors can insert own batches"
  ON public.course_batches FOR INSERT
  WITH CHECK (
    primary_mentor_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

DROP POLICY IF EXISTS "mentors can update own batches" ON public.course_batches;
CREATE POLICY "mentors can update own batches"
  ON public.course_batches FOR UPDATE
  USING  (primary_mentor_user_id = auth.uid())
  WITH CHECK (primary_mentor_user_id = auth.uid());

-- ── 4. Allow ALL authenticated users to SELECT published courses ─────────────
--    (needed for mentor/student to load course dropdown)
DROP POLICY IF EXISTS "authenticated can read published courses" ON public.courses;
CREATE POLICY "authenticated can read published courses"
  ON public.courses FOR SELECT
  USING (
    course_status = 'published'
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

-- ── 5. Allow mentors to read enrollments for their own batches ───────────────
DROP POLICY IF EXISTS "mentors can read own batch enrollments" ON public.enrollments;
CREATE POLICY "mentors can read own batch enrollments"
  ON public.enrollments FOR SELECT
  USING (
    student_user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.course_batches b
      JOIN public.mentor_profiles mp ON mp.user_id = auth.uid() AND mp.status = 'approved'
      WHERE b.id = enrollments.batch_id
        AND b.primary_mentor_user_id = auth.uid()
    )
  );
