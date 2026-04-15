-- v20: Fix course dropdown visibility for admin + mentor dashboards
-- Problem: courses_read_policy only grants SELECT via user_role_assignments
--          (is_admin()) but admin users are tracked via admin_profiles.
--          Approved mentors who are not yet assigned to a course via
--          course_mentor_assignments also get blocked.
-- Run in Supabase SQL Editor

-- ── 1. RPC function — returns all courses for dropdowns (SECURITY DEFINER) ──
--    Called by both admin and mentor dashboards to populate the course <select>.
--    Bypasses RLS entirely so it always returns results for authenticated users
--    who are admins or approved mentors.

CREATE OR REPLACE FUNCTION public.get_courses_for_dropdown()
RETURNS TABLE(id UUID, title TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  -- Only allow admins (admin_profiles) and approved mentors
  IF NOT EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = v_uid)
     AND NOT EXISTS (
       SELECT 1 FROM public.mentor_profiles mp
       WHERE mp.user_id = v_uid AND mp.status = 'approved'
     )
  THEN
    -- Regular users: return only published + public courses
    RETURN QUERY
      SELECT c.id, c.title
      FROM   public.courses c
      WHERE  c.course_status = 'published'
        AND  c.visibility IN ('public', 'unlisted')
      ORDER  BY c.title;
    RETURN;
  END IF;

  -- Admin / mentor: return ALL courses
  RETURN QUERY
    SELECT c.id, c.title
    FROM   public.courses c
    ORDER  BY c.title;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_courses_for_dropdown() TO authenticated;

-- ── 2. Also extend the courses RLS policy to cover admin_profiles users ──
--    This fixes any other query (not just the dropdown) that admins run.

DROP POLICY IF EXISTS courses_read_policy ON public.courses;

CREATE POLICY courses_read_policy ON public.courses FOR SELECT USING (
  -- Original conditions (v13)
  public.is_admin()
  OR EXISTS (
      SELECT 1 FROM public.course_mentor_assignments cma
      WHERE cma.course_id = courses.id
        AND cma.mentor_user_id = auth.uid()
        AND cma.is_active = TRUE
  )
  OR (courses.course_status = 'published' AND courses.visibility IN ('public', 'unlisted'))
  OR EXISTS (
      SELECT 1 FROM public.enrollments e
      WHERE e.course_id = courses.id
        AND e.student_user_id = auth.uid()
  )
  OR EXISTS (
      SELECT 1 FROM public.live_recordings lr
      WHERE lr.course_id = courses.id
        AND lr.is_published = TRUE
  )
  -- NEW: users tracked in admin_profiles (not just user_role_assignments)
  OR EXISTS (
      SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid()
  )
  -- NEW: approved mentors can read all courses (needed for batch creation)
  OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
  )
);

-- Clean up the duplicate policy added by v19 (superseded by the above)
DROP POLICY IF EXISTS "authenticated can read published courses" ON public.courses;
