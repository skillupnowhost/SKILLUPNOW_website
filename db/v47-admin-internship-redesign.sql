-- ============================================================
-- v47 — Admin Panel & Internship Redesign
-- Adds: scheduled_date + status columns to module tables,
--        slug auto-generation trigger on courses
-- Run AFTER v46-working-hours-gap-tracking.sql
-- ============================================================

-- ── 1. project_modules: add scheduled_date + status ─────────
ALTER TABLE public.project_modules
  ADD COLUMN IF NOT EXISTS scheduled_date DATE;

ALTER TABLE public.project_modules
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

-- Drop old constraint if exists, then add new one
DO $$ BEGIN
  ALTER TABLE public.project_modules
    DROP CONSTRAINT IF EXISTS project_modules_status_check;
  ALTER TABLE public.project_modules
    ADD CONSTRAINT project_modules_status_check
    CHECK (status IN ('active','completed','inactive','not_completed'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_pm_scheduled_date ON public.project_modules(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_pm_status ON public.project_modules(status);

-- ── 2. intern_program_modules: add scheduled_date + status ──
ALTER TABLE public.intern_program_modules
  ADD COLUMN IF NOT EXISTS scheduled_date DATE;

ALTER TABLE public.intern_program_modules
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

DO $$ BEGIN
  ALTER TABLE public.intern_program_modules
    DROP CONSTRAINT IF EXISTS intern_program_modules_status_check;
  ALTER TABLE public.intern_program_modules
    ADD CONSTRAINT intern_program_modules_status_check
    CHECK (status IN ('active','completed','inactive','not_completed'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_ipm_scheduled_date ON public.intern_program_modules(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_ipm_status ON public.intern_program_modules(status);

-- ── 3. intern_modules: update status constraint ─────────────
-- Currently allows ('assigned','in_progress','completed','reviewed')
-- Expand to also allow 'active','inactive','not_completed'
ALTER TABLE public.intern_modules
  ADD COLUMN IF NOT EXISTS scheduled_date DATE;

DO $$ BEGIN
  ALTER TABLE public.intern_modules
    DROP CONSTRAINT IF EXISTS intern_modules_status_check;
  ALTER TABLE public.intern_modules
    ADD CONSTRAINT intern_modules_status_check
    CHECK (status IN ('active','assigned','in_progress','completed','reviewed','inactive','not_completed'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_im_scheduled_date ON public.intern_modules(scheduled_date);

-- ── 4. Backfill existing data ───────────────────────────────
UPDATE public.project_modules
  SET scheduled_date = created_at::date
  WHERE scheduled_date IS NULL;

UPDATE public.project_modules
  SET status = CASE WHEN is_active THEN 'active' ELSE 'inactive' END
  WHERE status = 'active' AND is_active = false;

UPDATE public.intern_program_modules
  SET scheduled_date = created_at::date
  WHERE scheduled_date IS NULL;

UPDATE public.intern_program_modules
  SET status = CASE WHEN is_active THEN 'active' ELSE 'inactive' END
  WHERE status = 'active' AND is_active = false;

UPDATE public.intern_modules
  SET scheduled_date = created_at::date
  WHERE scheduled_date IS NULL;

-- ── 5. Slug auto-generation trigger on courses ──────────────
CREATE OR REPLACE FUNCTION public.auto_generate_course_slug()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := lower(regexp_replace(NEW.title, '[^a-zA-Z0-9\s]', '', 'g'));
    NEW.slug := regexp_replace(NEW.slug, '\s+', '-', 'g');
    NEW.slug := NEW.slug || '-' || extract(epoch from now())::bigint;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_course_auto_slug ON public.courses;
CREATE TRIGGER trg_course_auto_slug
  BEFORE INSERT OR UPDATE ON public.courses
  FOR EACH ROW EXECUTE FUNCTION public.auto_generate_course_slug();

-- ── 6. Grants ───────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON public.project_modules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.intern_program_modules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.intern_modules TO authenticated;
