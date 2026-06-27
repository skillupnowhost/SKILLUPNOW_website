-- v40: Allow students to insert/update their own attendance records
-- Required for auto-creating attendance when work sessions start/end

-- Student can insert own attendance
DROP POLICY IF EXISTS "ia_student_insert" ON public.internship_attendance;
CREATE POLICY "ia_student_insert" ON public.internship_attendance
  FOR INSERT WITH CHECK (student_user_id = auth.uid());

-- Student can update own attendance (for check_out_time)
DROP POLICY IF EXISTS "ia_student_update" ON public.internship_attendance;
CREATE POLICY "ia_student_update" ON public.internship_attendance
  FOR UPDATE USING (student_user_id = auth.uid());

-- Grant insert/update to authenticated users (select already granted)
GRANT INSERT, UPDATE ON public.internship_attendance TO authenticated;
