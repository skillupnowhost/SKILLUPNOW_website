-- v27: Explicit DELETE policies for reviews and feedback
-- Why: v26 policies rely on public.is_admin() which may not exist in all
--      environments. These policies use a direct user_profiles role check
--      so admin deletes work even if the helper function is missing.

-- ── reviews ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS reviews_delete_policy ON public.reviews;
CREATE POLICY reviews_delete_policy ON public.reviews
  FOR DELETE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  );

-- ── feedback ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS feedback_delete_policy ON public.feedback;
CREATE POLICY feedback_delete_policy ON public.feedback
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  );

-- ── reviews UPDATE (admin edit) ───────────────────────────────────────────────
DROP POLICY IF EXISTS reviews_update_policy ON public.reviews;
CREATE POLICY reviews_update_policy ON public.reviews
  FOR UPDATE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_id = auth.uid()
        AND role IN ('admin', 'super_admin')
    )
  );
