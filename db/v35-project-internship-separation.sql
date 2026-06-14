-- ============================================================
-- v35 — Project / Internship Separation
-- Adds internship_status column to distinguish internship lifecycle.
-- Run AFTER v34-paid-internships.sql has been applied.
-- ============================================================

-- ── Add internship_status for internship-type entries ──
ALTER TABLE public.internship_projects
  ADD COLUMN IF NOT EXISTS internship_status TEXT
    CHECK (internship_status IN ('upcoming', 'ongoing', 'completed'));

-- ── Default existing internship-type records to 'ongoing' ──
UPDATE public.internship_projects
SET internship_status = 'ongoing'
WHERE project_type = 'internship'
  AND internship_status IS NULL;

-- ── Index for fast status queries ──
CREATE INDEX IF NOT EXISTS idx_ip_internship_status ON public.internship_projects(internship_status)
  WHERE project_type = 'internship';

-- ── Update public read policy to expose internship_status ──
-- (policy already allows reading active rows; no changes needed for RLS)

-- ── Grant select on new column to authenticated/anon ──
GRANT SELECT (internship_status) ON public.internship_projects TO anon, authenticated;
