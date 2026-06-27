-- ============================================================
-- v39 — Internship Module Workflow
-- Mirrors the project_modules + project_assignments pattern
-- for the internship section.
-- Tables: intern_program_modules, intern_program_assignments
-- Run AFTER v38-tracking-fixes-and-projects.sql
-- ============================================================

-- ── 1. intern_program_modules ──────────────────────────────
-- Reusable modules per internship (like project_modules)
CREATE TABLE IF NOT EXISTS public.intern_program_modules (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  internship_id   uuid NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  module_name     text NOT NULL,
  description     text DEFAULT '',
  deadline        date,
  order_num       int  NOT NULL DEFAULT 0,
  is_active       boolean NOT NULL DEFAULT true,
  git_push_link   text,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_intern_program_modules_updated
  BEFORE UPDATE ON public.intern_program_modules
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── 2. intern_program_assignments ──────────────────────────
-- Assign module to user (like project_assignments)
CREATE TABLE IF NOT EXISTS public.intern_program_assignments (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  internship_id    uuid NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  module_id        uuid REFERENCES public.intern_program_modules(id) ON DELETE SET NULL,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_by      uuid NOT NULL REFERENCES auth.users(id),
  assigned_at      timestamptz NOT NULL DEFAULT now(),
  status           text NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active','in_progress','completed','revoked')),
  git_push_link    text,
  notes            text,
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(module_id, student_user_id)
);

CREATE TRIGGER trg_intern_program_assignments_updated
  BEFORE UPDATE ON public.intern_program_assignments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.intern_program_modules      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_program_assignments   ENABLE ROW LEVEL SECURITY;

-- intern_program_modules: public read of active, admin full control
CREATE POLICY "ipm_read_active" ON public.intern_program_modules
  FOR SELECT USING (is_active = true OR public._is_intern_admin());
CREATE POLICY "ipm_admin_all" ON public.intern_program_modules
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- intern_program_assignments: student sees own, admin full control
CREATE POLICY "ipa_student_select" ON public.intern_program_assignments
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "ipa_student_update" ON public.intern_program_assignments
  FOR UPDATE USING (student_user_id = auth.uid() AND status IN ('active','in_progress'));
CREATE POLICY "ipa_admin_all" ON public.intern_program_assignments
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_ipm_internship ON public.intern_program_modules(internship_id);
CREATE INDEX IF NOT EXISTS idx_ipm_active     ON public.intern_program_modules(is_active);
CREATE INDEX IF NOT EXISTS idx_ipa_internship ON public.intern_program_assignments(internship_id);
CREATE INDEX IF NOT EXISTS idx_ipa_module     ON public.intern_program_assignments(module_id);
CREATE INDEX IF NOT EXISTS idx_ipa_student    ON public.intern_program_assignments(student_user_id);
CREATE INDEX IF NOT EXISTS idx_ipa_status     ON public.intern_program_assignments(status);

-- ============================================================
-- GRANTS
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.intern_program_modules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.intern_program_assignments TO authenticated;

GRANT ALL ON public.intern_program_modules      TO service_role;
GRANT ALL ON public.intern_program_assignments   TO service_role;
