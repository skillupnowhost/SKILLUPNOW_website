-- v50: Fix infinite recursion on user_profiles + reviews RLS
-- Problem: v48 policies on mentor_profiles and user_profiles check admin role by
--          querying user_profiles directly. Since user_profiles SELECT policies
--          also query mentor_profiles, this creates a circular dependency:
--            user_profiles SELECT → mentor_profiles → user_profiles → ∞
-- Fix: Replace all direct user_profiles role lookups with is_admin() (SECURITY
--      DEFINER, bypasses RLS) or admin_profiles checks (separate table, no cycle).
-- Also fixes: v27 review/feedback policies that query user_profiles directly.
-- Run in Supabase SQL Editor. Safe to re-run; all statements are idempotent.

-- ══ SECTION 1: Sync admin role assignments (from v39) ═══════════════════════
-- Ensure every active admin_profiles user also has a user_role_assignments row.
-- This makes is_admin() return true for all dashboard admins.
CREATE OR REPLACE FUNCTION public.sync_admin_role_assignments()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_role_assignments (user_id, role, is_active, is_primary, assigned_reason)
  SELECT ap.user_id,
         COALESCE(
           (SELECT ura.role FROM public.user_role_assignments ura
            WHERE ura.user_id = ap.user_id AND ura.role IN ('admin','super_admin','support')
            LIMIT 1),
           'admin'
         ),
         true, true, 'auto-synced from admin_profiles'
  FROM public.admin_profiles ap
  WHERE ap.status = 'active'
    AND NOT EXISTS (
      SELECT 1 FROM public.user_role_assignments ura
      WHERE ura.user_id = ap.user_id
        AND ura.role IN ('admin','super_admin','support')
        AND ura.is_active = true
    )
  ON CONFLICT (user_id, role) DO UPDATE SET is_active = true;

  UPDATE public.user_role_assignments
  SET is_active = true
  WHERE role IN ('admin','super_admin','support')
    AND is_active = false
    AND user_id IN (
      SELECT user_id FROM public.admin_profiles WHERE status = 'active'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_admin_role_assignments() TO authenticated;
SELECT public.sync_admin_role_assignments();

-- ══ SECTION 2: Fix user_profiles SELECT (no self-reference) ═════════════════
-- Uses is_admin() and admin_profiles (both bypass user_profiles RLS).
-- Mentor check uses auth.uid() only (not user_profiles.user_id) to avoid
-- circular evaluation with mentor_profiles policies.
DROP POLICY IF EXISTS user_profiles_self_or_admin_select ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_select ON public.user_profiles;
DROP POLICY IF EXISTS "mentors can search user profiles" ON public.user_profiles;
CREATE POLICY user_profiles_self_or_admin_select ON public.user_profiles
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

-- Public profile visibility for users who have approved reviews (for website)
DROP POLICY IF EXISTS user_profiles_public_for_reviews ON public.user_profiles;
CREATE POLICY user_profiles_public_for_reviews ON public.user_profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.reviews r
      WHERE r.user_id = user_profiles.user_id AND r.is_approved = TRUE
    )
  );

-- ══ SECTION 3: Fix user_profiles UPDATE (remove self-reference from v48) ════
DROP POLICY IF EXISTS admin_update_any_profile ON public.user_profiles;
DROP POLICY IF EXISTS "admin_update_any_profile" ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_self_update ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_update ON public.user_profiles;
CREATE POLICY user_profiles_self_update ON public.user_profiles
  FOR UPDATE
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  )
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 4: Fix user_profiles INSERT ═════════════════════════════════════
DROP POLICY IF EXISTS user_profiles_self_insert ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_insert ON public.user_profiles;
CREATE POLICY user_profiles_self_insert ON public.user_profiles
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- ══ SECTION 5: Fix mentor_profiles policies (remove user_profiles ref) ══════
-- v48 admin_manage_mentors queried user_profiles → caused recursion.
-- Replace with is_admin() + admin_profiles.
DROP POLICY IF EXISTS "admin_manage_mentors" ON public.mentor_profiles;
DROP POLICY IF EXISTS mentor_profiles_read ON public.mentor_profiles;
DROP POLICY IF EXISTS mentor_profiles_read_policy ON public.mentor_profiles;
DROP POLICY IF EXISTS mentor_profiles_public_read ON public.mentor_profiles;
DROP POLICY IF EXISTS mentor_profiles_self_update ON public.mentor_profiles;

CREATE POLICY mentor_profiles_read_policy ON public.mentor_profiles
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR status = 'approved'
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

CREATE POLICY mentor_profiles_manage_policy ON public.mentor_profiles
  FOR ALL
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  )
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 6: Fix reviews policies (remove user_profiles ref from v27) ════
DROP POLICY IF EXISTS reviews_read_policy ON public.reviews;
CREATE POLICY reviews_read_policy ON public.reviews
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR is_approved = true
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

DROP POLICY IF EXISTS reviews_insert_policy ON public.reviews;
CREATE POLICY reviews_insert_policy ON public.reviews
  FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());

DROP POLICY IF EXISTS reviews_update_policy ON public.reviews;
CREATE POLICY reviews_update_policy ON public.reviews
  FOR UPDATE
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  )
  WITH CHECK (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

DROP POLICY IF EXISTS reviews_delete_policy ON public.reviews;
CREATE POLICY reviews_delete_policy ON public.reviews
  FOR DELETE
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 7: Fix feedback policies (remove user_profiles ref from v27) ════
DROP POLICY IF EXISTS feedback_read_policy ON public.feedback;
CREATE POLICY feedback_read_policy ON public.feedback
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

DROP POLICY IF EXISTS feedback_delete_policy ON public.feedback;
CREATE POLICY feedback_delete_policy ON public.feedback
  FOR DELETE
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 8: Fix remaining table policies ═════════════════════════════════
DROP POLICY IF EXISTS courses_read_policy ON public.courses;
CREATE POLICY courses_read_policy ON public.courses
  FOR SELECT
  USING (
    course_status = 'published'
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
    OR owner_admin_id = auth.uid()
  );

DROP POLICY IF EXISTS enrollments_read_policy ON public.enrollments;
CREATE POLICY enrollments_read_policy ON public.enrollments
  FOR SELECT
  USING (
    student_user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid() AND mp.status = 'approved'
    )
  );

DROP POLICY IF EXISTS payments_own_or_admin ON public.payments;
CREATE POLICY payments_own_or_admin ON public.payments
  FOR SELECT
  USING (
    student_user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

DROP POLICY IF EXISTS inquiries_read_policy ON public.inquiries;
CREATE POLICY inquiries_read_policy ON public.inquiries
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 9: Ensure GRANTs exist ═════════════════════════════════════════
GRANT SELECT ON TABLE public.user_profiles TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.user_profiles TO authenticated;
GRANT SELECT ON TABLE public.courses TO authenticated, anon;
GRANT SELECT ON TABLE public.course_categories TO authenticated, anon;
GRANT SELECT ON TABLE public.course_pricing TO authenticated, anon;
GRANT SELECT ON TABLE public.enrollments TO authenticated;
GRANT SELECT ON TABLE public.payments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.mentor_profiles TO authenticated;
GRANT SELECT ON TABLE public.reviews TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reviews TO authenticated;
GRANT SELECT ON TABLE public.feedback TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.feedback TO authenticated;
GRANT SELECT ON TABLE public.inquiries TO authenticated;
GRANT SELECT ON TABLE public.course_batches TO authenticated, anon;
GRANT SELECT ON TABLE public.user_role_assignments TO authenticated;
GRANT SELECT ON TABLE public.admin_profiles TO authenticated;

-- ══ SECTION 10: Auto-sync trigger (from v39) ═══════════════════════════════
CREATE OR REPLACE FUNCTION public.auto_sync_admin_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    INSERT INTO public.user_role_assignments (user_id, role, is_active, is_primary, assigned_reason)
    VALUES (NEW.user_id, 'admin', true, true, 'auto-synced from admin_profiles')
    ON CONFLICT (user_id, role) DO UPDATE SET is_active = true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_admin_role ON public.admin_profiles;
CREATE TRIGGER trg_sync_admin_role
  AFTER INSERT OR UPDATE ON public.admin_profiles
  FOR EACH ROW EXECUTE FUNCTION public.auto_sync_admin_role();
