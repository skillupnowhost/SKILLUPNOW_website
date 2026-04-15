-- ============================================================
-- v17 — Mentor Dashboard Rebuild
-- Adds: holidays, mentor_report_logs tables
-- Run in Supabase SQL Editor
-- ============================================================

-- ── HOLIDAYS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  holiday_name TEXT NOT NULL,
  holiday_date DATE NOT NULL,
  holiday_type TEXT NOT NULL DEFAULT 'national'
    CHECK (holiday_type IN ('national','local','religious','custom','Medical Leave')),
  description TEXT,
  is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
  affects_all_batches BOOLEAN NOT NULL DEFAULT TRUE,
  batch_ids UUID[] DEFAULT '{}',
  notify_students BOOLEAN NOT NULL DEFAULT TRUE,
  notify_admin BOOLEAN NOT NULL DEFAULT TRUE,
  notify_sent_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS holidays_select ON public.holidays;
CREATE POLICY holidays_select ON public.holidays
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS holidays_manage ON public.holidays;
CREATE POLICY holidays_manage ON public.holidays
  FOR ALL USING (
    public.is_admin() OR
    EXISTS (
      SELECT 1 FROM public.mentor_profiles
      WHERE user_id = auth.uid() AND status = 'approved'
    )
  ) WITH CHECK (
    public.is_admin() OR
    EXISTS (
      SELECT 1 FROM public.mentor_profiles
      WHERE user_id = auth.uid() AND status = 'approved'
    )
  );

-- ── MENTOR REPORT LOGS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.mentor_report_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id UUID NOT NULL REFERENCES public.mentor_profiles(user_id) ON DELETE CASCADE,
  report_type TEXT NOT NULL CHECK (report_type IN ('daily','weekly','monthly','custom')),
  report_date DATE NOT NULL,
  batch_id UUID REFERENCES public.course_batches(id) ON DELETE SET NULL,
  report_data JSONB NOT NULL DEFAULT '{}',
  sent_to_admin BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.mentor_report_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mentor_report_logs_select ON public.mentor_report_logs;
CREATE POLICY mentor_report_logs_select ON public.mentor_report_logs
  FOR SELECT USING (
    mentor_user_id = auth.uid() OR public.is_admin()
  );

DROP POLICY IF EXISTS mentor_report_logs_insert ON public.mentor_report_logs;
CREATE POLICY mentor_report_logs_insert ON public.mentor_report_logs
  FOR INSERT WITH CHECK (mentor_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS mentor_report_logs_update ON public.mentor_report_logs;
CREATE POLICY mentor_report_logs_update ON public.mentor_report_logs
  FOR UPDATE USING (mentor_user_id = auth.uid() OR public.is_admin());

-- ── ADD access_restriction_until TO enrollments (temp restriction) ──
ALTER TABLE public.enrollments
  ADD COLUMN IF NOT EXISTS access_restriction_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS restriction_reason TEXT,
  ADD COLUMN IF NOT EXISTS recording_access BOOLEAN NOT NULL DEFAULT TRUE;

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_holidays_date ON public.holidays (holiday_date);
CREATE INDEX IF NOT EXISTS idx_holidays_type ON public.holidays (holiday_type);
CREATE INDEX IF NOT EXISTS idx_mentor_report_logs_mentor ON public.mentor_report_logs (mentor_user_id, report_date);

-- ── Seed common Indian public holidays 2025-2026 ──────────────
INSERT INTO public.holidays (holiday_name, holiday_date, holiday_type, description, is_recurring)
VALUES
  ('Republic Day', '2026-01-26', 'national', 'National Holiday — India', TRUE),
  ('Holi', '2026-03-14', 'religious', 'Festival of Colors', TRUE),
  ('Good Friday', '2026-04-03', 'religious', 'Christian Holiday', TRUE),
  ('Dr. Ambedkar Jayanti', '2026-04-14', 'national', 'National Holiday', TRUE),
  ('Ram Navami', '2026-04-02', 'religious', 'Hindu Festival', TRUE),
  ('Independence Day', '2026-08-15', 'national', 'National Holiday — India', TRUE),
  ('Gandhi Jayanti', '2026-10-02', 'national', 'National Holiday', TRUE),
  ('Dussehra', '2026-10-11', 'religious', 'Hindu Festival', TRUE),
  ('Diwali', '2026-10-29', 'religious', 'Festival of Lights', TRUE),
  ('Guru Nanak Jayanti', '2026-11-14', 'religious', 'Sikh Holiday', TRUE),
  ('Christmas', '2026-12-25', 'religious', 'Christian Holiday', TRUE)
ON CONFLICT DO NOTHING;
