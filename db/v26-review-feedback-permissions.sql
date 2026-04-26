-- v26: Public read access for reviews, feedback, and related tables
-- Why:
--   - Reviews and approved feedback must be readable by ALL visitors (anon),
--     not just logged-in users. PostgREST checks GRANTs on every table in a
--     join, so `courses` and `user_profiles` also need anon SELECT grants.
--   - feedback_read_policy previously blocked anon entirely — updated to allow
--     reading reviewed/resolved feedback that has a rating (homepage display).
--   - mentor_profiles needs anon SELECT for the public pamphlet/brochure page.

-- ── Schema usage ────────────────────────────────────────────────────────────
GRANT USAGE ON SCHEMA public TO authenticated, anon;

-- ── Authenticated users ──────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reviews          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.feedback         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.form_submissions TO authenticated;

-- ── Anon (public) GRANTs ─────────────────────────────────────────────────────
-- reviews — approved rows only (enforced by RLS below)
GRANT SELECT ON TABLE public.reviews          TO anon;
GRANT INSERT ON TABLE public.reviews          TO anon;

-- feedback — reviewed/resolved rows with ratings only (RLS below)
GRANT SELECT ON TABLE public.feedback         TO anon;
GRANT INSERT ON TABLE public.feedback         TO anon;
GRANT INSERT ON TABLE public.form_submissions TO anon;

-- courses — public catalogue info needed for the reviews join
GRANT SELECT ON TABLE public.courses          TO anon;

-- user_profiles — display name + city needed for review cards (RLS restricts to review authors)
GRANT SELECT ON TABLE public.user_profiles    TO anon;

-- mentor_profiles — public brochure/pamphlet page
GRANT SELECT ON TABLE public.mentor_profiles  TO anon;

-- ── Enable RLS ───────────────────────────────────────────────────────────────
ALTER TABLE public.reviews          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_profiles  ENABLE ROW LEVEL SECURITY;

-- ── reviews policies ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS reviews_read_policy ON public.reviews;
CREATE POLICY reviews_read_policy ON public.reviews
  FOR SELECT
  USING (is_approved = TRUE OR user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS reviews_insert_policy ON public.reviews;
CREATE POLICY reviews_insert_policy ON public.reviews
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());

DROP POLICY IF EXISTS reviews_update_policy ON public.reviews;
CREATE POLICY reviews_update_policy ON public.reviews
  FOR UPDATE
  USING  (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS reviews_delete_policy ON public.reviews;
CREATE POLICY reviews_delete_policy ON public.reviews
  FOR DELETE
  USING (user_id = auth.uid() OR public.is_admin());

-- ── feedback policies ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS feedback_read_policy ON public.feedback;
CREATE POLICY feedback_read_policy ON public.feedback
  FOR SELECT
  USING (
    -- logged-in users see their own feedback
    user_id = auth.uid()
    OR mentor_user_id = auth.uid()
    OR public.is_admin()
    -- public visitors see only reviewed/resolved entries that have a rating
    OR (status IN ('reviewed', 'resolved') AND rating IS NOT NULL)
  );

DROP POLICY IF EXISTS feedback_insert_policy ON public.feedback;
CREATE POLICY feedback_insert_policy ON public.feedback
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());

DROP POLICY IF EXISTS feedback_update_policy ON public.feedback;
CREATE POLICY feedback_update_policy ON public.feedback
  FOR UPDATE
  USING  (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS feedback_delete_policy ON public.feedback;
CREATE POLICY feedback_delete_policy ON public.feedback
  FOR DELETE
  USING (public.is_admin());

-- ── user_profiles policies ────────────────────────────────────────────────────
-- Existing self/admin policy — keep it
DROP POLICY IF EXISTS user_profiles_self_or_admin_select ON public.user_profiles;
CREATE POLICY user_profiles_self_or_admin_select ON public.user_profiles
  FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

-- New: allow anon to read display fields of users who have approved reviews
DROP POLICY IF EXISTS user_profiles_public_for_reviews ON public.user_profiles;
CREATE POLICY user_profiles_public_for_reviews ON public.user_profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.reviews r
      WHERE r.user_id = user_profiles.user_id AND r.is_approved = TRUE
    )
  );

DROP POLICY IF EXISTS user_profiles_self_insert ON public.user_profiles;
CREATE POLICY user_profiles_self_insert ON public.user_profiles
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS user_profiles_self_update ON public.user_profiles;
CREATE POLICY user_profiles_self_update ON public.user_profiles
  FOR UPDATE
  USING  (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- ── mentor_profiles policies ──────────────────────────────────────────────────
DROP POLICY IF EXISTS mentor_profiles_public_read ON public.mentor_profiles;
CREATE POLICY mentor_profiles_public_read ON public.mentor_profiles
  FOR SELECT
  USING (
    status != 'rejected'         -- public brochure sees all non-rejected mentors
    OR user_id = auth.uid()
    OR public.is_admin()
  );

-- ── form_submissions policies ─────────────────────────────────────────────────
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
  USING  (public.is_admin())
  WITH CHECK (public.is_admin());
