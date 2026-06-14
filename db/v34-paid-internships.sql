-- ============================================================
-- v34 — Paid Internship Support
-- Run AFTER internship-schema.sql has been applied.
-- ============================================================

-- ── Add paid flag + amount to internship_projects ──
ALTER TABLE public.internship_projects
  ADD COLUMN IF NOT EXISTS is_paid         BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS payment_amount  NUMERIC(10,2);

-- ── Public application table (no login required for free) ──
CREATE TABLE IF NOT EXISTS public.internship_applications (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  internship_id   UUID        REFERENCES public.internship_projects(id) ON DELETE SET NULL,
  name            TEXT        NOT NULL,
  email           TEXT        NOT NULL,
  phone           TEXT        NOT NULL,
  college_name    TEXT        NOT NULL,
  year_of_study   TEXT,
  programme       TEXT,
  message         TEXT,
  user_id         UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  status          TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending','reviewing','accepted','rejected')),
  payment_id      TEXT,
  payment_status  TEXT        NOT NULL DEFAULT 'none'
                              CHECK (payment_status IN ('none','paid','failed','refunded')),
  payment_amount  NUMERIC(10,2),
  applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_internship_applications_updated_at
  BEFORE UPDATE ON public.internship_applications
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── RLS ──
ALTER TABLE public.internship_applications ENABLE ROW LEVEL SECURITY;

-- Anyone can insert a new application (public form)
DROP POLICY IF EXISTS "iapp_public_insert" ON public.internship_applications;
CREATE POLICY "iapp_public_insert" ON public.internship_applications
  FOR INSERT WITH CHECK (true);

-- Logged-in user can view their own applications
DROP POLICY IF EXISTS "iapp_self_select" ON public.internship_applications;
CREATE POLICY "iapp_self_select" ON public.internship_applications
  FOR SELECT USING (user_id = auth.uid() OR user_id IS NULL OR public._is_intern_admin());

-- Admins have full access
DROP POLICY IF EXISTS "iapp_admin_all" ON public.internship_applications;
CREATE POLICY "iapp_admin_all" ON public.internship_applications
  FOR ALL USING (public._is_intern_admin());

-- ── Indexes ──
CREATE INDEX IF NOT EXISTS idx_iapp_internship ON public.internship_applications(internship_id);
CREATE INDEX IF NOT EXISTS idx_iapp_email      ON public.internship_applications(email);
CREATE INDEX IF NOT EXISTS idx_iapp_status     ON public.internship_applications(status);
CREATE INDEX IF NOT EXISTS idx_iapp_paid       ON public.internship_projects(is_paid);
