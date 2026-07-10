-- ============================================================
-- v52: Fix missing DELETE grants on intern/project tracking tables
--
-- Root cause: Postgres checks table-level GRANTs before RLS
-- policies are evaluated. v37/v38 created "FOR ALL" admin RLS
-- policies (e.g. sub_admin_all on intern_submissions) but never
-- GRANTed DELETE to the `authenticated` role — only SELECT,
-- INSERT, UPDATE. So admin deletes fail with
-- "permission denied for table X" before RLS even runs.
--
-- This grants DELETE on all affected tables. RLS still restricts
-- actual delete access to admins via _is_intern_admin().
-- Safe to re-run.
-- ============================================================

GRANT DELETE ON public.intern_submissions    TO authenticated;
GRANT DELETE ON public.intern_work_sessions  TO authenticated;
GRANT DELETE ON public.intern_breaks         TO authenticated;
GRANT DELETE ON public.intern_app_usage      TO authenticated;
GRANT DELETE ON public.intern_git_permissions TO authenticated;
GRANT DELETE ON public.intern_admin_reports  TO authenticated;

GRANT DELETE ON public.project_submissions   TO authenticated;
GRANT DELETE ON public.project_app_usage     TO authenticated;
GRANT DELETE ON public.project_admin_reports TO authenticated;
