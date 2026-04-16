-- v22: Fix four critical bugs + access-management columns
-- Bugs addressed:
--   1. "Could not find the 'session_description' column" — add it to class_sessions
--   2. "new row violates RLS for table enrollments" — extend INSERT/UPDATE policies
--      to recognise admin_profiles users (is_admin() only checks user_role_assignments)
--   3. "permission denied for table mentor_profiles" on Schedule Class —
--      refresh_mentor_stats and handle_class_session_refresh run SECURITY INVOKER;
--      when an admin (not in user_role_assignments) triggers the trigger it can't
--      UPDATE a mentor's profile row.  Fix: SECURITY DEFINER on those functions.
--   4. enrollments → user_profiles join: student_profiles FK already bridges this;
--      no schema change needed — just JS query fix (see mentor-dashboard.html patch).
-- Run in Supabase SQL Editor.

-- ── 1. session_description column ───────────────────────────────────────────
ALTER TABLE public.class_sessions
  ADD COLUMN IF NOT EXISTS session_description TEXT;

-- ── 2. Enrollment INSERT — allow admin_profiles users ────────────────────────
DROP POLICY IF EXISTS enrollments_insert_own_or_admin ON public.enrollments;
CREATE POLICY enrollments_insert_own_or_admin ON public.enrollments
  FOR INSERT WITH CHECK (
    student_user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    -- approved mentors can enrol students into their own batches
    OR EXISTS (
      SELECT 1 FROM public.course_batches cb
      JOIN public.mentor_profiles mp ON mp.user_id = auth.uid()
      WHERE cb.id = enrollments.batch_id
        AND cb.primary_mentor_user_id = auth.uid()
        AND mp.status = 'approved'
    )
  );

-- ── 3. Enrollment UPDATE — allow admin_profiles users ────────────────────────
DROP POLICY IF EXISTS enrollments_update_admin_only ON public.enrollments;
CREATE POLICY enrollments_update_admin_only ON public.enrollments
  FOR UPDATE
  USING (
    student_user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.course_batches cb
      JOIN public.mentor_profiles mp ON mp.user_id = auth.uid()
      WHERE cb.id = enrollments.batch_id
        AND cb.primary_mentor_user_id = auth.uid()
        AND mp.status = 'approved'
    )
  )
  WITH CHECK (
    student_user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.course_batches cb
      JOIN public.mentor_profiles mp ON mp.user_id = auth.uid()
      WHERE cb.id = enrollments.batch_id
        AND cb.primary_mentor_user_id = auth.uid()
        AND mp.status = 'approved'
    )
  );

-- ── 4. Make refresh_mentor_stats SECURITY DEFINER ────────────────────────────
--    This function is called from a trigger (handle_class_session_refresh /
--    handle_batch_enrollment_change) and needs to UPDATE mentor_profiles rows
--    that belong to *another* user when an admin schedules a class.
CREATE OR REPLACE FUNCTION public.refresh_mentor_stats(p_mentor_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_mentor_user_id IS NULL THEN RETURN; END IF;

  UPDATE public.mentor_profiles m
  SET
    total_classes_assigned = COALESCE((
      SELECT COUNT(*) FROM public.class_sessions cs
      WHERE cs.mentor_user_id = p_mentor_user_id
    ), 0),
    total_students_managed = COALESCE((
      SELECT COUNT(DISTINCT e.student_user_id)
      FROM public.course_batches b
      JOIN public.enrollments e ON e.batch_id = b.id
      WHERE b.primary_mentor_user_id = p_mentor_user_id
        AND e.enrollment_status IN ('pending', 'active', 'completed')
    ), 0),
    updated_at = NOW()
  WHERE m.user_id = p_mentor_user_id;
END;
$$;

-- ── 5. Make handle_class_session_refresh SECURITY DEFINER ────────────────────
CREATE OR REPLACE FUNCTION public.handle_class_session_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.refresh_mentor_stats(OLD.mentor_user_id);
    RETURN OLD;
  END IF;
  PERFORM public.refresh_mentor_stats(NEW.mentor_user_id);
  RETURN NEW;
END;
$$;

-- ── 6. Make handle_batch_enrollment_change SECURITY DEFINER ──────────────────
--    Same issue: when an admin/mentor enrols a student, this trigger needs to
--    UPDATE course_batches (current_student_count) which requires the caller to
--    have write access to that row.
CREATE OR REPLACE FUNCTION public.handle_batch_enrollment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_batch_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    p_batch_id := OLD.batch_id;
  ELSE
    p_batch_id := NEW.batch_id;
  END IF;

  IF p_batch_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  UPDATE public.course_batches b
  SET current_student_count = COALESCE((
    SELECT COUNT(*)
    FROM public.enrollments e
    WHERE e.batch_id = b.id
      AND e.enrollment_status IN ('pending', 'active', 'completed')
  ), 0),
  updated_at = NOW()
  WHERE b.id = p_batch_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ── 7. recording_access + video_access_until on enrollments (if not present) ─
ALTER TABLE public.enrollments
  ADD COLUMN IF NOT EXISTS recording_access BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS video_access_until TIMESTAMPTZ;

-- ── 8. Extend SELECT policy on enrollments to cover approved mentors ──────────
--    (v21 already did this for the recursive case; keep it here for completeness)
DROP POLICY IF EXISTS enrollments_own_or_admin_or_mentor ON public.enrollments;
CREATE POLICY enrollments_own_or_admin_or_mentor ON public.enrollments FOR SELECT USING (
  student_user_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.mentor_profiles mp
    WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
  )
);

-- ── 9. student_profiles SELECT — allow admin_profiles users and approved mentors ─
--    The base policy (student_profiles_self_or_admin) only calls is_admin() which
--    checks user_role_assignments.  Admin-dashboard and mentor-dashboard users
--    stored in admin_profiles / mentor_profiles therefore get "permission denied".
DROP POLICY IF EXISTS student_profiles_self_or_admin ON public.student_profiles;
CREATE POLICY student_profiles_self_or_admin ON public.student_profiles FOR ALL
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

-- ── 10. Diagnostic: confirm FK constraint names on student_profiles → user_profiles
--    Run this SELECT to see the exact names used in PostgREST hints.
--    The JS code uses: user_profiles!student_profiles_user_id_fkey(...)
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.student_profiles'::regclass
  AND contype = 'f';
