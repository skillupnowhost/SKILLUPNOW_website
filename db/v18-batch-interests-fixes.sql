-- v18: Batch description + course_interests fixes + trigger SECURITY DEFINER
-- Run in Supabase SQL Editor

-- ── 1. Add description column to course_batches ──────────────────────────────
ALTER TABLE public.course_batches
  ADD COLUMN IF NOT EXISTS description TEXT;

-- ── 2. Fix trigger functions — must be SECURITY DEFINER so they can UPDATE ──
--    mentor_profiles even when called by the authenticated (non-service) role.
--    Without this, INSERT/UPDATE on course_batches throws
--    "permission denied for table mentor_profiles".

CREATE OR REPLACE FUNCTION public.handle_mentor_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER          -- ← runs as table owner, bypasses row-level security
SET search_path = public  -- ← security best-practice with SECURITY DEFINER
AS $$
DECLARE
  p_mentor_user_id UUID;
BEGIN
  -- Determine which mentor to refresh
  IF TG_OP = 'DELETE' THEN
    p_mentor_user_id := OLD.primary_mentor_user_id;
  ELSE
    p_mentor_user_id := NEW.primary_mentor_user_id;
  END IF;

  IF p_mentor_user_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  UPDATE public.mentor_profiles
  SET
    total_classes_assigned = COALESCE((
      SELECT COUNT(*) FROM public.class_sessions cs WHERE cs.mentor_user_id = p_mentor_user_id
    ), 0),
    total_students_managed = COALESCE((
      SELECT COUNT(DISTINCT e.student_user_id)
      FROM public.course_batches b
      JOIN public.enrollments e ON e.batch_id = b.id
      WHERE b.primary_mentor_user_id = p_mentor_user_id
        AND e.enrollment_status IN ('pending', 'active', 'completed')
    ), 0),
    updated_at = NOW()
  WHERE user_id = p_mentor_user_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_batch_student_count()
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

-- Re-attach triggers (DROP+CREATE to refresh the SECURITY DEFINER setting)
DROP TRIGGER IF EXISTS trg_batches_refresh_mentor ON public.course_batches;
CREATE TRIGGER trg_batches_refresh_mentor
AFTER INSERT OR UPDATE OR DELETE ON public.course_batches
FOR EACH ROW EXECUTE FUNCTION public.handle_mentor_refresh();

DROP TRIGGER IF EXISTS trg_batch_student_count ON public.enrollments;
CREATE TRIGGER trg_batch_student_count
AFTER INSERT OR UPDATE OR DELETE ON public.enrollments
FOR EACH ROW EXECUTE FUNCTION public.handle_batch_student_count();

-- ── 3. Add missing columns to course_interests ───────────────────────────────
ALTER TABLE public.course_interests
  ADD COLUMN IF NOT EXISTS notified_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS discount_code TEXT;

-- ── 4. Fix course_interests RLS + GRANTs ────────────────────────────────────
-- The authenticated role needs explicit GRANTs; RLS policies alone aren't enough.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_interests TO authenticated;
GRANT SELECT                          ON public.course_interests TO anon;

-- Fix the broken SELECT policy that references non-existent 'profiles' table
DROP POLICY IF EXISTS "admins can read interests" ON public.course_interests;
CREATE POLICY "users can read own interests"
  ON public.course_interests FOR SELECT
  USING (
    student_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid()
    )
  );

-- Ensure INSERT policy exists (idempotent)
DROP POLICY IF EXISTS "users can upsert own interest" ON public.course_interests;
CREATE POLICY "users can insert own interest"
  ON public.course_interests FOR INSERT
  WITH CHECK (student_user_id = auth.uid());

-- Ensure UPDATE policy exists (needed for upsert ON CONFLICT)
DROP POLICY IF EXISTS "users can update own interest" ON public.course_interests;
CREATE POLICY "users can update own interest"
  ON public.course_interests FOR UPDATE
  USING  (student_user_id = auth.uid())
  WITH CHECK (student_user_id = auth.uid());

-- Admin full access
DROP POLICY IF EXISTS "admins can delete interests" ON public.course_interests;
CREATE POLICY "admins full access interests"
  ON public.course_interests FOR ALL
  USING (EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid()));

-- ── 5. Index for fast "unnotified" queries ───────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_course_interests_notified
  ON public.course_interests (course_id, notified_at)
  WHERE notified_at IS NULL;
