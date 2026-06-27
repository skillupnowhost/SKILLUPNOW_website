-- ============================================================
-- SKILLUPNOW V44 — FIX admin_delete_user() AND TRIGGER
-- Run in Supabase SQL editor
-- Date: 2026-06-27
-- Purpose:
--   Fix "relation public.admin_users does not exist" error
--   by replacing all admin_users references with admin_profiles
--   in both admin_delete_user() RPC and the BEFORE DELETE trigger.
--   Also adds admin_profiles.status check instead of is_active.
-- ============================================================


-- ── PART 1: Fix admin_delete_user() RPC ─────────────────────

DROP FUNCTION IF EXISTS public.admin_delete_user(UUID);

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  caller_id UUID;
BEGIN
  -- Auth guard: check both admin_profiles and user_role_assignments
  caller_id := auth.uid();
  IF caller_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: must be logged in'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.admin_profiles WHERE user_id = caller_id AND status = 'active'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.user_role_assignments
    WHERE user_id = caller_id AND role IN ('admin', 'super_admin', 'support') AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Unauthorized: admin access required';
  END IF;

  IF caller_id = target_user_id THEN
    RAISE EXCEPTION 'Forbidden: cannot delete your own account';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = target_user_id) THEN
    RAISE EXCEPTION 'User not found: %', target_user_id;
  END IF;

  -- Reassign courses owned by this admin
  UPDATE public.courses SET owner_admin_id = caller_id
    WHERE owner_admin_id = target_user_id AND caller_id != target_user_id;

  -- Delete in dependency order
  DELETE FROM public.payment_schedules ps
    USING public.enrollments e
    WHERE ps.enrollment_id = e.id AND e.student_user_id = target_user_id;

  DELETE FROM public.payments WHERE student_user_id = target_user_id;
  DELETE FROM public.enrollments WHERE student_user_id = target_user_id;
  DELETE FROM public.reviews WHERE user_id = target_user_id;

  BEGIN DELETE FROM public.inquiries WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.form_submissions WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.notifications WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.class_attendance WHERE student_user_id = target_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  BEGIN DELETE FROM public.video_access_sessions WHERE student_user_id = target_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  BEGIN DELETE FROM public.course_access_logs WHERE student_user_id = target_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  BEGIN DELETE FROM public.feedback WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  UPDATE public.course_batches SET primary_mentor_user_id = NULL
    WHERE primary_mentor_user_id = target_user_id;
  DELETE FROM public.class_sessions WHERE mentor_user_id = target_user_id;
  DELETE FROM public.course_mentor_assignments WHERE mentor_user_id = target_user_id;
  DELETE FROM public.course_mentor_assignments WHERE assigned_by_admin_id = target_user_id;

  BEGIN
    DELETE FROM public.mentor_salary_payments WHERE mentor_user_id = target_user_id;
    DELETE FROM public.mentor_performance_reports WHERE mentor_user_id = target_user_id;
    DELETE FROM public.mentor_documents WHERE mentor_user_id = target_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  DELETE FROM public.mentor_profiles WHERE user_id = target_user_id;

  BEGIN DELETE FROM public.admin_portal_access WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.admin_login_otp_challenges WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  DELETE FROM public.admin_profiles WHERE user_id = target_user_id;
  DELETE FROM public.student_profiles WHERE user_id = target_user_id;

  BEGIN DELETE FROM public.user_role_assignments WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.auth_activity_logs WHERE user_id = target_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  DELETE FROM public.user_profiles WHERE user_id = target_user_id;

  -- Remove auth user (must be last)
  DELETE FROM auth.users WHERE id = target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'deleted_user_id', target_user_id::text,
    'message', 'User and all data permanently deleted. Email is free to re-register.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated;


-- ── PART 2: Fix handle_auth_user_before_delete() trigger ────

CREATE OR REPLACE FUNCTION public.handle_auth_user_before_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  fallback_admin UUID;
BEGIN
  -- Payment schedules linked via enrollments
  DELETE FROM public.payment_schedules ps
    USING public.enrollments e
    WHERE ps.enrollment_id = e.id AND e.student_user_id = OLD.id;

  DELETE FROM public.payments WHERE student_user_id = OLD.id;
  DELETE FROM public.enrollments WHERE student_user_id = OLD.id;
  DELETE FROM public.reviews WHERE user_id = OLD.id;

  BEGIN DELETE FROM public.inquiries WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.form_submissions WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.notifications WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.class_attendance WHERE student_user_id = OLD.id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  BEGIN DELETE FROM public.video_access_sessions WHERE student_user_id = OLD.id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  BEGIN DELETE FROM public.course_access_logs WHERE student_user_id = OLD.id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  BEGIN DELETE FROM public.feedback WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  -- Reassign courses to another active admin
  IF EXISTS (SELECT 1 FROM public.courses WHERE owner_admin_id = OLD.id) THEN
    SELECT user_id INTO fallback_admin
      FROM public.admin_profiles
      WHERE user_id != OLD.id AND status = 'active'
      LIMIT 1;
    IF fallback_admin IS NOT NULL THEN
      UPDATE public.courses SET owner_admin_id = fallback_admin WHERE owner_admin_id = OLD.id;
    ELSE
      RAISE EXCEPTION 'Cannot delete user: they own courses and no other active admin exists. Reassign courses first.';
    END IF;
  END IF;

  UPDATE public.course_batches SET primary_mentor_user_id = NULL
    WHERE primary_mentor_user_id = OLD.id;

  DELETE FROM public.class_sessions WHERE mentor_user_id = OLD.id;
  DELETE FROM public.course_mentor_assignments WHERE mentor_user_id = OLD.id;
  DELETE FROM public.course_mentor_assignments WHERE assigned_by_admin_id = OLD.id;

  BEGIN
    DELETE FROM public.mentor_salary_payments WHERE mentor_user_id = OLD.id;
    DELETE FROM public.mentor_performance_reports WHERE mentor_user_id = OLD.id;
    DELETE FROM public.mentor_documents WHERE mentor_user_id = OLD.id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  DELETE FROM public.mentor_profiles WHERE user_id = OLD.id;

  BEGIN DELETE FROM public.admin_portal_access WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.admin_login_otp_challenges WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  DELETE FROM public.admin_profiles WHERE user_id = OLD.id;
  DELETE FROM public.student_profiles WHERE user_id = OLD.id;

  BEGIN DELETE FROM public.user_role_assignments WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  BEGIN DELETE FROM public.auth_activity_logs WHERE user_id = OLD.id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL; END;

  DELETE FROM public.user_profiles WHERE user_id = OLD.id;

  RETURN OLD;
END;
$$;

-- Re-attach the trigger
DROP TRIGGER IF EXISTS trg_before_auth_user_delete ON auth.users;
CREATE TRIGGER trg_before_auth_user_delete
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user_before_delete();


-- ── PART 3: Ensure delete RLS policy on payments ────────────
-- (may already exist from v29, safe to re-run)
DROP POLICY IF EXISTS payments_admin_delete ON public.payments;
CREATE POLICY payments_admin_delete ON public.payments
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.user_id = auth.uid())
    OR public.is_admin()
  );

-- ── DONE ─────────────────────────────────────────────────────
-- After running:
--   1. admin_delete_user() no longer references non-existent admin_users table
--   2. The BEFORE DELETE trigger uses admin_profiles with status='active'
--   3. Both user and mentor deletion from admin dashboard will work
