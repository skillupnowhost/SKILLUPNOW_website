-- v27: Fix holiday management permissions for dashboard users
-- Run this in Supabase SQL Editor so admin dashboard holiday create/edit/delete works.

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.holidays TO authenticated;

-- Keep holiday reads open for dashboard views while RLS controls writes.
ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS holidays_select ON public.holidays;
CREATE POLICY holidays_select ON public.holidays
  FOR SELECT
  USING (TRUE);

DROP POLICY IF EXISTS holidays_manage ON public.holidays;
CREATE POLICY holidays_manage ON public.holidays
  FOR ALL
  USING (
    public.is_admin() OR
    EXISTS (
      SELECT 1
      FROM public.mentor_profiles
      WHERE user_id = auth.uid()
        AND status = 'approved'
    )
  )
  WITH CHECK (
    public.is_admin() OR
    EXISTS (
      SELECT 1
      FROM public.mentor_profiles
      WHERE user_id = auth.uid()
        AND status = 'approved'
    )
  );
