-- ============================================================
-- SKILLUPNOW v29 — PAYMENTS TABLE: Admin INSERT/UPDATE policy
-- ============================================================
-- Problem: Admin gets "permission denied for table payments"
--   when trying to create payment records via the admin panel.
--   The payments table has no INSERT/UPDATE RLS policy for admins.
--
-- Run this ONCE in Supabase SQL Editor:
--   Dashboard → SQL Editor → paste this file → Run
-- ============================================================

-- 1. Grant table-level privileges to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.payments TO authenticated;

-- 2. RLS policy: admin can INSERT any payment
DROP POLICY IF EXISTS payments_admin_insert ON public.payments;
CREATE POLICY payments_admin_insert
  ON public.payments
  FOR INSERT
  WITH CHECK (public.is_admin());

-- 3. RLS policy: admin can UPDATE any payment
DROP POLICY IF EXISTS payments_admin_update ON public.payments;
CREATE POLICY payments_admin_update
  ON public.payments
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 4. Students can INSERT their own payments (for Razorpay flow)
DROP POLICY IF EXISTS payments_own_insert ON public.payments;
CREATE POLICY payments_own_insert
  ON public.payments
  FOR INSERT
  WITH CHECK (student_user_id = auth.uid());

-- 5. Students can SELECT their own payments (keep existing or recreate)
DROP POLICY IF EXISTS payments_own_or_admin ON public.payments;
CREATE POLICY payments_own_or_admin
  ON public.payments
  FOR SELECT
  USING (student_user_id = auth.uid() OR public.is_admin());

-- 6. Admin can DELETE payments (already in v9 but safe to re-apply)
DROP POLICY IF EXISTS payments_admin_delete ON public.payments;
CREATE POLICY payments_admin_delete
  ON public.payments
  FOR DELETE
  USING (public.is_admin());

DO $$
BEGIN
  RAISE NOTICE 'v29 applied: payments table now has admin INSERT/UPDATE/DELETE RLS policies.';
END;
$$;
