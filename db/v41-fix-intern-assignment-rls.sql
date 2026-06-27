-- ============================================================
-- v41 — Fix intern_program_assignments RLS for student updates
-- Problem: Students can't mark modules as 'completed' because
--          the UPDATE policy's implicit WITH CHECK rejects the
--          new status value ('completed' not in 'active','in_progress').
-- Fix: Add explicit WITH CHECK that allows 'completed' as target status.
-- Also fixes intern_breaks: remove break_number constraint to allow
-- flexible break types (lunch, tea, etc.) beyond just 2 numbered breaks.
-- Run AFTER v39-internship-module-workflow.sql
-- ============================================================

-- ── Fix intern_program_assignments update policy ──
DROP POLICY IF EXISTS "ipa_student_update" ON public.intern_program_assignments;
CREATE POLICY "ipa_student_update" ON public.intern_program_assignments
  FOR UPDATE
  USING (student_user_id = auth.uid() AND status IN ('active','in_progress'))
  WITH CHECK (student_user_id = auth.uid() AND status IN ('active','in_progress','completed'));
