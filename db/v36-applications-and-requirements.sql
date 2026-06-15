-- ============================================================
-- v36: internship_applications + project_requirements tables
-- Run in Supabase SQL Editor to fix permission denied errors.
-- ============================================================

-- ── 1. internship_applications table ─────────────────────────
CREATE TABLE IF NOT EXISTS public.internship_applications (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  full_name        text NOT NULL,
  email            text NOT NULL,
  phone            text,
  college_name     text,
  year_of_study    text,
  programme_id     uuid REFERENCES public.internship_projects(id) ON DELETE SET NULL,
  programme_name   text,
  message          text,
  user_id          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status           text DEFAULT 'pending' CHECK (status IN ('pending','reviewing','accepted','rejected')),
  is_paid          boolean DEFAULT false,
  amount_paid      numeric(12,2),
  payment_id       text,
  submitted_at     timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE public.internship_applications ENABLE ROW LEVEL SECURITY;

-- Drop stale policies
DROP POLICY IF EXISTS "ia_anon_insert"     ON public.internship_applications;
DROP POLICY IF EXISTS "ia_auth_insert"     ON public.internship_applications;
DROP POLICY IF EXISTS "ia_user_select"     ON public.internship_applications;
DROP POLICY IF EXISTS "ia_admin_all"       ON public.internship_applications;

-- Any authenticated user can submit an application
CREATE POLICY "ia_auth_insert" ON public.internship_applications
  FOR INSERT
  WITH CHECK (true);  -- allow anyone (auth + anon) to submit

-- Anon can also insert (for non-logged-in paid submissions)
CREATE POLICY "ia_anon_insert" ON public.internship_applications
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Users can view their own applications
CREATE POLICY "ia_user_select" ON public.internship_applications
  FOR SELECT USING (user_id = auth.uid() OR public._is_intern_admin());

-- Admins can do everything
CREATE POLICY "ia_admin_all" ON public.internship_applications
  FOR ALL
  USING     (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- Grant access
GRANT SELECT, INSERT ON public.internship_applications TO anon, authenticated;
GRANT ALL ON public.internship_applications TO service_role;

-- ── 2. project_requirements table ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.project_requirements (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  company_name    text NOT NULL,
  contact_email   text NOT NULL,
  contact_phone   text,
  domain          text,
  project_title   text NOT NULL,
  requirements    text NOT NULL,
  tech_stack      text,
  timeline        text,
  budget          text,
  status          text DEFAULT 'pending' CHECK (status IN ('pending','reviewed','contacted','converted')),
  submitted_at    timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

ALTER TABLE public.project_requirements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pr_anon_insert"  ON public.project_requirements;
DROP POLICY IF EXISTS "pr_auth_insert"  ON public.project_requirements;
DROP POLICY IF EXISTS "pr_admin_all"    ON public.project_requirements;

-- Anyone can submit project requirements (public form)
CREATE POLICY "pr_anon_insert" ON public.project_requirements
  FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "pr_auth_insert" ON public.project_requirements
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Only admins can read/update/delete
CREATE POLICY "pr_admin_all" ON public.project_requirements
  FOR ALL
  USING     (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT INSERT ON public.project_requirements TO anon, authenticated;
GRANT ALL    ON public.project_requirements TO service_role;
GRANT SELECT, UPDATE, DELETE ON public.project_requirements TO authenticated;

-- ── VERIFY ───────────────────────────────────────────────────
-- SELECT count(*) FROM public.internship_applications;
-- SELECT count(*) FROM public.project_requirements;
-- Both should return without error.
