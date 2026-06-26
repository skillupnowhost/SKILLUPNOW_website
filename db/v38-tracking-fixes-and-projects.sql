-- ============================================================
-- v38 — Fix Permission Errors + Daily Modules + Project Tracking
-- Fixes: app_usage RLS/grants, module grants, WITH CHECK on all FOR ALL
-- Adds: day_number to intern_modules, project_app_usage,
--       project_submissions, project_admin_reports, session assignments
-- Run AFTER v37-intern-tracking.sql
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- PART 1: FIX PERMISSION DENIED ERRORS
-- ════════════════════════════════════════════════════════════

-- ── 1a. Fix intern_app_usage: add SELECT grant + WITH CHECK ──
GRANT SELECT, INSERT ON public.intern_app_usage TO authenticated;

DROP POLICY IF EXISTS "au_admin_only_select" ON public.intern_app_usage;
DROP POLICY IF EXISTS "au_system_insert"     ON public.intern_app_usage;
DROP POLICY IF EXISTS "au_admin_all"         ON public.intern_app_usage;

CREATE POLICY "au_system_insert" ON public.intern_app_usage
  FOR INSERT TO authenticated
  WITH CHECK (student_user_id = auth.uid());

CREATE POLICY "au_admin_select" ON public.intern_app_usage
  FOR SELECT TO authenticated
  USING (public._is_intern_admin());

CREATE POLICY "au_admin_all" ON public.intern_app_usage
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ── 1b. Fix intern_modules: add INSERT grant + WITH CHECK ──
GRANT SELECT, INSERT, UPDATE, DELETE ON public.intern_modules TO authenticated;

DROP POLICY IF EXISTS "mod_student_select" ON public.intern_modules;
DROP POLICY IF EXISTS "mod_student_update" ON public.intern_modules;
DROP POLICY IF EXISTS "mod_admin_all"      ON public.intern_modules;

CREATE POLICY "mod_student_select" ON public.intern_modules
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "mod_student_update" ON public.intern_modules
  FOR UPDATE USING (student_user_id = auth.uid() AND status IN ('assigned','in_progress'));
CREATE POLICY "mod_admin_all" ON public.intern_modules
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ── 1c. Fix intern_work_sessions WITH CHECK ──
DROP POLICY IF EXISTS "ws_admin_all" ON public.intern_work_sessions;
CREATE POLICY "ws_admin_all" ON public.intern_work_sessions
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ── 1d. Fix intern_breaks WITH CHECK ──
DROP POLICY IF EXISTS "br_admin_all" ON public.intern_breaks;
CREATE POLICY "br_admin_all" ON public.intern_breaks
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ── 1e. Fix intern_submissions: add UPDATE grant + WITH CHECK ──
GRANT SELECT, INSERT, UPDATE ON public.intern_submissions TO authenticated;

DROP POLICY IF EXISTS "sub_admin_all" ON public.intern_submissions;
CREATE POLICY "sub_admin_all" ON public.intern_submissions
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ── 1f. Fix intern_git_permissions WITH CHECK ──
GRANT SELECT, INSERT, UPDATE ON public.intern_git_permissions TO authenticated;

DROP POLICY IF EXISTS "gp_admin_all" ON public.intern_git_permissions;
CREATE POLICY "gp_admin_all" ON public.intern_git_permissions
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

-- ── 1g. Fix intern_admin_reports WITH CHECK ──
GRANT SELECT, INSERT, UPDATE ON public.intern_admin_reports TO authenticated;

DROP POLICY IF EXISTS "ar_admin_only" ON public.intern_admin_reports;
CREATE POLICY "ar_admin_only" ON public.intern_admin_reports
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());


-- ════════════════════════════════════════════════════════════
-- PART 2: ENHANCE INTERN MODULES WITH DAY-WISE TASKS
-- ════════════════════════════════════════════════════════════

ALTER TABLE public.intern_modules
  ADD COLUMN IF NOT EXISTS day_number      int CHECK (day_number >= 1 AND day_number <= 50),
  ADD COLUMN IF NOT EXISTS task_type       text DEFAULT 'daily'
    CHECK (task_type IN ('daily','milestone','review','assessment')),
  ADD COLUMN IF NOT EXISTS estimated_hours numeric(4,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS resources_url   text;


-- ════════════════════════════════════════════════════════════
-- PART 3: INTERN SESSION ASSIGNMENTS (assign specific tasks to users within sessions)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.intern_session_tasks (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid NOT NULL REFERENCES public.intern_work_sessions(id) ON DELETE CASCADE,
  enrollment_id    uuid NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  module_id        uuid REFERENCES public.intern_modules(id) ON DELETE SET NULL,
  task_title       text NOT NULL,
  task_desc        text DEFAULT '',
  assigned_by      uuid REFERENCES auth.users(id),
  status           text NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','in_progress','completed','blocked')),
  started_at       timestamptz,
  completed_at     timestamptz,
  admin_notes      text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_intern_session_tasks_updated
  BEFORE UPDATE ON public.intern_session_tasks
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.intern_session_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ist_student_select" ON public.intern_session_tasks
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "ist_student_update" ON public.intern_session_tasks
  FOR UPDATE USING (student_user_id = auth.uid() AND status IN ('pending','in_progress'));
CREATE POLICY "ist_admin_all" ON public.intern_session_tasks
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, UPDATE ON public.intern_session_tasks TO authenticated;
GRANT ALL ON public.intern_session_tasks TO service_role;

CREATE INDEX IF NOT EXISTS idx_ist_session  ON public.intern_session_tasks(session_id);
CREATE INDEX IF NOT EXISTS idx_ist_student  ON public.intern_session_tasks(student_user_id);
CREATE INDEX IF NOT EXISTS idx_ist_module   ON public.intern_session_tasks(module_id);
CREATE INDEX IF NOT EXISTS idx_ist_enroll   ON public.intern_session_tasks(enrollment_id);


-- ════════════════════════════════════════════════════════════
-- PART 4: PROJECT APP USAGE TRACKING (mirrors intern_app_usage)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.project_app_usage (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid NOT NULL REFERENCES public.project_work_sessions(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  app_name         text NOT NULL,
  window_title     text DEFAULT '',
  active_seconds   int NOT NULL DEFAULT 0,
  recorded_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.project_app_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pau_system_insert" ON public.project_app_usage
  FOR INSERT TO authenticated
  WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "pau_admin_select" ON public.project_app_usage
  FOR SELECT TO authenticated
  USING (public._is_intern_admin());
CREATE POLICY "pau_admin_all" ON public.project_app_usage
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, INSERT ON public.project_app_usage TO authenticated;
GRANT ALL ON public.project_app_usage TO service_role;

CREATE INDEX IF NOT EXISTS idx_pau_session  ON public.project_app_usage(session_id);
CREATE INDEX IF NOT EXISTS idx_pau_student  ON public.project_app_usage(student_user_id);


-- ════════════════════════════════════════════════════════════
-- PART 5: PROJECT SUBMISSIONS (mirrors intern_submissions)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.project_submissions (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  assignment_id    uuid NOT NULL REFERENCES public.project_assignments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id       uuid REFERENCES public.project_work_sessions(id) ON DELETE SET NULL,
  submission_title text NOT NULL DEFAULT '',
  description      text DEFAULT '',
  screenshot_url   text,
  report_file_url  text,
  report_file_type text CHECK (report_file_type IN ('pdf','xlsx','xls',NULL)),
  commit_message   text DEFAULT '',
  status           text NOT NULL DEFAULT 'submitted'
                   CHECK (status IN ('submitted','reviewed','approved','rejected')),
  admin_feedback   text,
  reviewed_by      uuid REFERENCES auth.users(id),
  reviewed_at      timestamptz,
  submitted_at     timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_project_submissions_updated
  BEFORE UPDATE ON public.project_submissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.project_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "psub_student_select" ON public.project_submissions
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "psub_student_insert" ON public.project_submissions
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "psub_admin_all" ON public.project_submissions
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, INSERT, UPDATE ON public.project_submissions TO authenticated;
GRANT ALL ON public.project_submissions TO service_role;

CREATE INDEX IF NOT EXISTS idx_psub_student ON public.project_submissions(student_user_id);
CREATE INDEX IF NOT EXISTS idx_psub_assign  ON public.project_submissions(assignment_id);


-- ════════════════════════════════════════════════════════════
-- PART 6: PROJECT ADMIN REPORTS (mirrors intern_admin_reports)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.project_admin_reports (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  submission_id    uuid NOT NULL REFERENCES public.project_submissions(id) ON DELETE CASCADE,
  assignment_id    uuid NOT NULL REFERENCES public.project_assignments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_date      date NOT NULL DEFAULT CURRENT_DATE,
  work_duration    int DEFAULT 0,
  apps_used        jsonb DEFAULT '[]'::jsonb,
  modules_status   jsonb DEFAULT '[]'::jsonb,
  git_pushes       int DEFAULT 0,
  notes            text DEFAULT '',
  generated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.project_admin_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "par_admin_only" ON public.project_admin_reports
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, INSERT, UPDATE ON public.project_admin_reports TO authenticated;
GRANT ALL ON public.project_admin_reports TO service_role;

CREATE INDEX IF NOT EXISTS idx_par_sub     ON public.project_admin_reports(submission_id);
CREATE INDEX IF NOT EXISTS idx_par_student ON public.project_admin_reports(student_user_id);


-- ════════════════════════════════════════════════════════════
-- PART 7: PROJECT SESSION TASKS (mirrors intern_session_tasks)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.project_session_tasks (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid NOT NULL REFERENCES public.project_work_sessions(id) ON DELETE CASCADE,
  assignment_id    uuid NOT NULL REFERENCES public.project_assignments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  module_id        uuid REFERENCES public.project_modules(id) ON DELETE SET NULL,
  task_title       text NOT NULL,
  task_desc        text DEFAULT '',
  assigned_by      uuid REFERENCES auth.users(id),
  status           text NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','in_progress','completed','blocked')),
  started_at       timestamptz,
  completed_at     timestamptz,
  admin_notes      text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_project_session_tasks_updated
  BEFORE UPDATE ON public.project_session_tasks
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.project_session_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pst_student_select" ON public.project_session_tasks
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pst_student_update" ON public.project_session_tasks
  FOR UPDATE USING (student_user_id = auth.uid() AND status IN ('pending','in_progress'));
CREATE POLICY "pst_admin_all" ON public.project_session_tasks
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, UPDATE ON public.project_session_tasks TO authenticated;
GRANT ALL ON public.project_session_tasks TO service_role;

CREATE INDEX IF NOT EXISTS idx_pst_session  ON public.project_session_tasks(session_id);
CREATE INDEX IF NOT EXISTS idx_pst_student  ON public.project_session_tasks(student_user_id);
CREATE INDEX IF NOT EXISTS idx_pst_module   ON public.project_session_tasks(module_id);
CREATE INDEX IF NOT EXISTS idx_pst_assign   ON public.project_session_tasks(assignment_id);


-- ════════════════════════════════════════════════════════════
-- PART 8: ENHANCE PROJECT MODULES WITH DAY-WISE TASKS
-- ════════════════════════════════════════════════════════════

ALTER TABLE public.project_modules
  ADD COLUMN IF NOT EXISTS day_number      int CHECK (day_number >= 1),
  ADD COLUMN IF NOT EXISTS task_type       text DEFAULT 'daily'
    CHECK (task_type IN ('daily','milestone','review','assessment')),
  ADD COLUMN IF NOT EXISTS estimated_hours numeric(4,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS resources_url   text;


-- ════════════════════════════════════════════════════════════
-- PART 9: PROJECT PAYMENT TRACKING (client pays, not user)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.project_client_payments (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id       uuid NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  client_name      text NOT NULL,
  client_email     text,
  client_phone     text,
  payment_amount   numeric(12,2) NOT NULL,
  currency         text NOT NULL DEFAULT 'INR',
  payment_status   text NOT NULL DEFAULT 'pending'
                   CHECK (payment_status IN ('pending','paid','partial','refunded','cancelled')),
  payment_id       text,
  payment_method   text DEFAULT 'razorpay',
  invoice_number   text,
  notes            text,
  paid_at          timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_project_client_payments_updated
  BEFORE UPDATE ON public.project_client_payments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.project_client_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pcp_admin_only" ON public.project_client_payments
  FOR ALL USING (public._is_intern_admin())
  WITH CHECK (public._is_intern_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.project_client_payments TO authenticated;
GRANT ALL ON public.project_client_payments TO service_role;

CREATE INDEX IF NOT EXISTS idx_pcp_project ON public.project_client_payments(project_id);
CREATE INDEX IF NOT EXISTS idx_pcp_status  ON public.project_client_payments(payment_status);


-- ════════════════════════════════════════════════════════════
-- PART 10: STORAGE BUCKET FOR PROJECT SUBMISSIONS
-- ════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public)
VALUES ('project-submissions', 'project-submissions', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "proj_sub_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'project-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "proj_sub_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'project-submissions'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public._is_intern_admin()
    )
  );


-- ════════════════════════════════════════════════════════════
-- VERIFY
-- ════════════════════════════════════════════════════════════
-- SELECT has_table_privilege('authenticated','public.intern_app_usage','INSERT');
-- SELECT has_table_privilege('authenticated','public.intern_app_usage','SELECT');
-- SELECT has_table_privilege('authenticated','public.project_app_usage','INSERT');
-- SELECT has_table_privilege('authenticated','public.intern_modules','INSERT');
-- All should return TRUE.
