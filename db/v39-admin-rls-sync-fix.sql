-- v39: Admin Dashboard RLS Sync Fix
-- Problem: Admin dashboard shows all zeros because RLS policies block data access.
-- Root cause: Some policies use is_admin() (checks user_role_assignments),
--             others check admin_profiles. If user_role_assignments row is missing
--             or is_active=false, data queries silently return empty results.
-- Fix: Ensure all critical SELECT policies also check admin_profiles as fallback,
--       and add a sync function to ensure user_role_assignments stays in sync.
-- Run in Supabase SQL Editor.

-- ══ SECTION 1: Sync admin role assignments ══════════════════════════════════════
-- Ensures every active admin_profiles user also has a user_role_assignments row.
-- This fixes the root cause: is_admin() returns false because user_role_assignments
-- row was never created or was deactivated.

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

  -- Also re-activate any deactivated admin role assignments
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

-- Run the sync immediately
SELECT public.sync_admin_role_assignments();

-- ══ SECTION 2: Fix user_profiles SELECT policy ═════════════════════════════════
-- Ensure admin can read ALL user profiles (needed for user list, profile maps)
DROP POLICY IF EXISTS user_profiles_self_or_admin_select ON public.user_profiles;
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
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = user_profiles.user_id AND mp.status = 'approved'
    )
  );

-- ══ SECTION 3: Fix courses SELECT policy ════════════════════════════════════════
DROP POLICY IF EXISTS courses_read_policy ON public.courses;
CREATE POLICY courses_read_policy ON public.courses
  FOR SELECT
  USING (
    course_status = 'published'
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
    OR owner_admin_id = auth.uid()
  );

-- ══ SECTION 4: Fix enrollments SELECT policy ════════════════════════════════════
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

-- ══ SECTION 5: Fix payments SELECT policy ═══════════════════════════════════════
DROP POLICY IF EXISTS payments_own_or_admin ON public.payments;
CREATE POLICY payments_own_or_admin ON public.payments
  FOR SELECT
  USING (
    student_user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 6: Fix mentor_profiles SELECT policy ════════════════════════════════
DROP POLICY IF EXISTS mentor_profiles_read_policy ON public.mentor_profiles;
CREATE POLICY mentor_profiles_read_policy ON public.mentor_profiles
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
    OR status = 'approved'
  );

-- ══ SECTION 7: Fix reviews SELECT policy ════════════════════════════════════════
DROP POLICY IF EXISTS reviews_read_policy ON public.reviews;
CREATE POLICY reviews_read_policy ON public.reviews
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR is_approved = true
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 8: Fix feedback SELECT policy ═══════════════════════════════════════
DROP POLICY IF EXISTS feedback_read_policy ON public.feedback;
CREATE POLICY feedback_read_policy ON public.feedback
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 9: Fix inquiries SELECT policy ══════════════════════════════════════
DROP POLICY IF EXISTS inquiries_read_policy ON public.inquiries;
CREATE POLICY inquiries_read_policy ON public.inquiries
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
  );

-- ══ SECTION 10: Fix course_categories SELECT policy ═════════════════════════════
DROP POLICY IF EXISTS categories_read_policy ON public.course_categories;
CREATE POLICY categories_read_policy ON public.course_categories
  FOR SELECT
  USING (true);

-- ══ SECTION 11: Fix course_pricing SELECT policy ════════════════════════════════
DROP POLICY IF EXISTS pricing_read_policy ON public.course_pricing;
CREATE POLICY pricing_read_policy ON public.course_pricing
  FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid() AND ap.status = 'active')
    OR EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_pricing.course_id AND c.course_status = 'published'
    )
  );

-- ══ SECTION 12: Ensure GRANTs exist ═════════════════════════════════════════════
GRANT SELECT ON TABLE public.user_profiles TO authenticated, anon;
GRANT SELECT ON TABLE public.courses TO authenticated, anon;
GRANT SELECT ON TABLE public.course_categories TO authenticated, anon;
GRANT SELECT ON TABLE public.course_pricing TO authenticated, anon;
GRANT SELECT ON TABLE public.enrollments TO authenticated;
GRANT SELECT ON TABLE public.payments TO authenticated;
GRANT SELECT ON TABLE public.mentor_profiles TO authenticated, anon;
GRANT SELECT ON TABLE public.reviews TO authenticated, anon;
GRANT SELECT ON TABLE public.feedback TO authenticated;
GRANT SELECT ON TABLE public.inquiries TO authenticated;
GRANT SELECT ON TABLE public.course_batches TO authenticated, anon;
GRANT SELECT ON TABLE public.user_role_assignments TO authenticated;
GRANT SELECT ON TABLE public.admin_profiles TO authenticated;

-- ══ SECTION 13: Auto-sync trigger ═══════════════════════════════════════════════
-- When admin_profiles is inserted/updated, auto-sync user_role_assignments
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
