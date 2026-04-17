-- v26: Fix missing GRANTs for reviews / feedback / form_submissions
-- Why:
--   - The feedback page submits course reviews into public.reviews.
--   - Mentor/admin/website feedback submits into public.feedback and mirrors into public.form_submissions.
--   - RLS policies already exist in schema.sql, but PostgreSQL checks table GRANTs first.
--   - Without GRANTs, browser requests fail with errors like:
--       "permission denied for table reviews"

GRANT USAGE ON SCHEMA public TO authenticated, anon;

-- Authenticated users:
--   Students can create/update their own reviews.
--   Admins can moderate reviews and manage feedback/forms.
--   RLS policies still enforce row-level access.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reviews          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.feedback         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.form_submissions TO authenticated;

-- Public / anon access:
--   Landing page + footer review sections read approved reviews using the anon key.
--   Website/admin feedback forms may be submitted without login, so anon needs INSERT.
GRANT SELECT ON TABLE public.reviews TO anon;
GRANT INSERT ON TABLE public.feedback TO anon;
GRANT INSERT ON TABLE public.form_submissions TO anon;

-- Keep RLS explicit here as a safety net if the target project predates these policies.
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reviews_read_policy ON public.reviews;
CREATE POLICY reviews_read_policy ON public.reviews
  FOR SELECT
  USING (is_approved = TRUE OR user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS reviews_insert_policy ON public.reviews;
CREATE POLICY reviews_insert_policy ON public.reviews
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS reviews_update_policy ON public.reviews;
CREATE POLICY reviews_update_policy ON public.reviews
  FOR UPDATE
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS feedback_read_policy ON public.feedback;
CREATE POLICY feedback_read_policy ON public.feedback
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR mentor_user_id = auth.uid()
    OR public.is_admin()
  );

DROP POLICY IF EXISTS feedback_insert_policy ON public.feedback;
CREATE POLICY feedback_insert_policy ON public.feedback
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());

DROP POLICY IF EXISTS feedback_update_policy ON public.feedback;
CREATE POLICY feedback_update_policy ON public.feedback
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS form_submissions_read_policy ON public.form_submissions;
CREATE POLICY form_submissions_read_policy ON public.form_submissions
  FOR SELECT
  USING (
    submitted_by_user_id = auth.uid()
    OR user_id = auth.uid()
    OR public.is_admin()
  );

DROP POLICY IF EXISTS form_submissions_insert_policy ON public.form_submissions;
CREATE POLICY form_submissions_insert_policy ON public.form_submissions
  FOR INSERT
  WITH CHECK (
    submitted_by_user_id = auth.uid()
    OR user_id = auth.uid()
    OR (submitted_by_user_id IS NULL AND user_id IS NULL)
    OR public.is_admin()
  );

DROP POLICY IF EXISTS form_submissions_update_policy ON public.form_submissions;
CREATE POLICY form_submissions_update_policy ON public.form_submissions
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
