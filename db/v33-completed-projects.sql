-- ============================================================
-- SKILLUPNOW — COMPLETED PROJECTS
-- v33: Adds 'completed' to project_type CHECK constraint
--      Run AFTER v32-session-fix.sql
-- ============================================================

ALTER TABLE public.internship_projects
  DROP CONSTRAINT IF EXISTS internship_projects_project_type_check;

ALTER TABLE public.internship_projects
  ADD CONSTRAINT internship_projects_project_type_check
  CHECK (project_type IN ('available', 'internship', 'upcoming', 'completed'));

-- ============================================================
-- VERIFY:
--   INSERT INTO public.internship_projects (project_name, project_type, ...)
--     VALUES ('Test Completed', 'completed', ...);
--   → should succeed now
-- ============================================================
