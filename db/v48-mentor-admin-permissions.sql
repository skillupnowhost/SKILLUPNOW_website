-- ============================================================
-- v48 — Fix admin permissions for mentor editing
-- Allows admins to update user_profiles and delete mentors
-- Run AFTER v47-admin-internship-redesign.sql
-- ============================================================

-- ── 1. Admin RLS policy for user_profiles UPDATE ────────────
-- The error "permission denied for table user_profiles" occurs because
-- the admin user cannot update other users' profiles via RLS.

-- Drop existing restrictive update policies and add admin-capable ones
DO $$ BEGIN
  -- Allow admins to update any user_profile
  DROP POLICY IF EXISTS "admin_update_any_profile" ON public.user_profiles;
  CREATE POLICY "admin_update_any_profile" ON public.user_profiles
    FOR UPDATE USING (
      auth.uid() = user_id
      OR EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.user_id = auth.uid()
        AND up.role IN ('admin', 'super_admin')
      )
    )
    WITH CHECK (
      auth.uid() = user_id
      OR EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.user_id = auth.uid()
        AND up.role IN ('admin', 'super_admin')
      )
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Policy creation failed: %', SQLERRM;
END $$;

-- ── 2. Admin RLS policy for mentor_profiles full access ─────
DO $$ BEGIN
  DROP POLICY IF EXISTS "admin_manage_mentors" ON public.mentor_profiles;
  CREATE POLICY "admin_manage_mentors" ON public.mentor_profiles
    FOR ALL USING (
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.user_id = auth.uid()
        AND up.role IN ('admin', 'super_admin')
      )
    )
    WITH CHECK (
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.user_id = auth.uid()
        AND up.role IN ('admin', 'super_admin')
      )
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Policy creation failed: %', SQLERRM;
END $$;

-- ── 3. Ensure DELETE grant on mentor_profiles ───────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mentor_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_profiles TO authenticated;

-- ── 4. RPC for admin to update user role safely ─────────────
-- Drop existing function first (may have different return type)
DROP FUNCTION IF EXISTS public.admin_update_user_role(uuid, text);

CREATE FUNCTION public.admin_update_user_role(p_user_id uuid, p_new_role text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Verify caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.user_profiles
  SET role = p_new_role, updated_at = now()
  WHERE user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_user_role(uuid, text) TO authenticated;
