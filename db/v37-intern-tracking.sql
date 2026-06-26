-- ============================================================
-- v37 — Advanced Internship Tracking System
-- Tables: work sessions, breaks, modules, app usage,
--         submissions, git permissions, admin reports
-- Run AFTER v36-applications-and-requirements.sql
-- ============================================================

-- ── 1. intern_work_sessions ─────────────────────────────────
-- Tracks daily start/end work times per student
CREATE TABLE IF NOT EXISTS public.intern_work_sessions (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  enrollment_id    uuid NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_date     date NOT NULL DEFAULT CURRENT_DATE,
  start_time       timestamptz,
  end_time         timestamptz,
  total_work_mins  int GENERATED ALWAYS AS (
    CASE WHEN start_time IS NOT NULL AND end_time IS NOT NULL
         THEN EXTRACT(EPOCH FROM (end_time - start_time))::int / 60
         ELSE 0 END
  ) STORED,
  status           text NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','completed','auto_closed')),
  day_number       int NOT NULL DEFAULT 1 CHECK (day_number >= 1 AND day_number <= 50),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(enrollment_id, session_date)
);

CREATE TRIGGER trg_work_sessions_updated
  BEFORE UPDATE ON public.intern_work_sessions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── 2. intern_breaks ────────────────────────────────────────
-- Two scheduled breaks per work day (10AM-6PM window)
CREATE TABLE IF NOT EXISTS public.intern_breaks (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid NOT NULL REFERENCES public.intern_work_sessions(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  break_number     int NOT NULL CHECK (break_number IN (1, 2)),
  break_start      timestamptz,
  break_end        timestamptz,
  duration_mins    int GENERATED ALWAYS AS (
    CASE WHEN break_start IS NOT NULL AND break_end IS NOT NULL
         THEN EXTRACT(EPOCH FROM (break_end - break_start))::int / 60
         ELSE 0 END
  ) STORED,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(session_id, break_number)
);

-- ── 3. intern_modules ───────────────────────────────────────
-- Modules assigned by admin to students
CREATE TABLE IF NOT EXISTS public.intern_modules (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  enrollment_id    uuid NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  module_title     text NOT NULL,
  module_desc      text DEFAULT '',
  assigned_by      uuid REFERENCES auth.users(id),
  due_date         date,
  status           text NOT NULL DEFAULT 'assigned'
                   CHECK (status IN ('assigned','in_progress','completed','reviewed')),
  sort_order       int NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_intern_modules_updated
  BEFORE UPDATE ON public.intern_modules
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── 4. intern_app_usage (confidential — admin only) ─────────
-- Background tracking of app usage (VS Code, Chrome, etc.)
-- Students NEVER see this data
CREATE TABLE IF NOT EXISTS public.intern_app_usage (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid NOT NULL REFERENCES public.intern_work_sessions(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  app_name         text NOT NULL,
  window_title     text DEFAULT '',
  active_seconds   int NOT NULL DEFAULT 0,
  recorded_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 5. intern_submissions ───────────────────────────────────
-- Student submissions with screenshot + report file
CREATE TABLE IF NOT EXISTS public.intern_submissions (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  enrollment_id    uuid NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id       uuid REFERENCES public.intern_work_sessions(id) ON DELETE SET NULL,
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

CREATE TRIGGER trg_intern_submissions_updated
  BEFORE UPDATE ON public.intern_submissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── 6. intern_git_permissions ───────────────────────────────
-- Admin grants explicit git push permission per student
CREATE TABLE IF NOT EXISTS public.intern_git_permissions (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  enrollment_id    uuid NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  repo_url         text NOT NULL,
  branch_name      text NOT NULL DEFAULT 'main',
  is_active        boolean NOT NULL DEFAULT true,
  granted_by       uuid NOT NULL REFERENCES auth.users(id),
  granted_at       timestamptz NOT NULL DEFAULT now(),
  revoked_at       timestamptz,
  UNIQUE(enrollment_id, repo_url)
);

-- ── 7. intern_admin_reports ─────────────────────────────────
-- Per-submission detailed reports visible only to admins
CREATE TABLE IF NOT EXISTS public.intern_admin_reports (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  submission_id    uuid NOT NULL REFERENCES public.intern_submissions(id) ON DELETE CASCADE,
  enrollment_id    uuid NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_date      date NOT NULL DEFAULT CURRENT_DATE,
  work_duration    int DEFAULT 0,
  break_duration   int DEFAULT 0,
  apps_used        jsonb DEFAULT '[]'::jsonb,
  modules_status   jsonb DEFAULT '[]'::jsonb,
  git_pushes       int DEFAULT 0,
  attendance_day   int DEFAULT 0,
  notes            text DEFAULT '',
  generated_at     timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.intern_work_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_breaks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_modules        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_app_usage      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_submissions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_git_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intern_admin_reports  ENABLE ROW LEVEL SECURITY;

-- ── Work Sessions: students see own, admins see all ──
CREATE POLICY "ws_student_select" ON public.intern_work_sessions
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "ws_student_insert" ON public.intern_work_sessions
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "ws_student_update" ON public.intern_work_sessions
  FOR UPDATE USING (student_user_id = auth.uid());
CREATE POLICY "ws_admin_all" ON public.intern_work_sessions
  FOR ALL USING (public._is_intern_admin());

-- ── Breaks: students see own, admins see all ──
CREATE POLICY "br_student_select" ON public.intern_breaks
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "br_student_insert" ON public.intern_breaks
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "br_student_update" ON public.intern_breaks
  FOR UPDATE USING (student_user_id = auth.uid());
CREATE POLICY "br_admin_all" ON public.intern_breaks
  FOR ALL USING (public._is_intern_admin());

-- ── Modules: students see own, admins manage all ──
CREATE POLICY "mod_student_select" ON public.intern_modules
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "mod_student_update" ON public.intern_modules
  FOR UPDATE USING (student_user_id = auth.uid() AND status IN ('assigned','in_progress'));
CREATE POLICY "mod_admin_all" ON public.intern_modules
  FOR ALL USING (public._is_intern_admin());

-- ── App Usage: ADMIN ONLY — students must NEVER see this ──
CREATE POLICY "au_admin_only_select" ON public.intern_app_usage
  FOR SELECT USING (public._is_intern_admin());
CREATE POLICY "au_system_insert" ON public.intern_app_usage
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "au_admin_all" ON public.intern_app_usage
  FOR ALL USING (public._is_intern_admin());

-- ── Submissions: students see/insert own, admins manage all ──
CREATE POLICY "sub_student_select" ON public.intern_submissions
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "sub_student_insert" ON public.intern_submissions
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "sub_admin_all" ON public.intern_submissions
  FOR ALL USING (public._is_intern_admin());

-- ── Git Permissions: students see own, admins manage all ──
CREATE POLICY "gp_student_select" ON public.intern_git_permissions
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "gp_admin_all" ON public.intern_git_permissions
  FOR ALL USING (public._is_intern_admin());

-- ── Admin Reports: ADMIN ONLY ──
CREATE POLICY "ar_admin_only" ON public.intern_admin_reports
  FOR ALL USING (public._is_intern_admin());

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_ws_student    ON public.intern_work_sessions(student_user_id);
CREATE INDEX IF NOT EXISTS idx_ws_enroll     ON public.intern_work_sessions(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_ws_date       ON public.intern_work_sessions(session_date);
CREATE INDEX IF NOT EXISTS idx_br_session    ON public.intern_breaks(session_id);
CREATE INDEX IF NOT EXISTS idx_mod_student   ON public.intern_modules(student_user_id);
CREATE INDEX IF NOT EXISTS idx_mod_enroll    ON public.intern_modules(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_au_session    ON public.intern_app_usage(session_id);
CREATE INDEX IF NOT EXISTS idx_au_student    ON public.intern_app_usage(student_user_id);
CREATE INDEX IF NOT EXISTS idx_sub_student   ON public.intern_submissions(student_user_id);
CREATE INDEX IF NOT EXISTS idx_sub_enroll    ON public.intern_submissions(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_gp_student    ON public.intern_git_permissions(student_user_id);
CREATE INDEX IF NOT EXISTS idx_gp_enroll     ON public.intern_git_permissions(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_ar_sub        ON public.intern_admin_reports(submission_id);
CREATE INDEX IF NOT EXISTS idx_ar_student    ON public.intern_admin_reports(student_user_id);

-- ============================================================
-- GRANTS
-- ============================================================

GRANT SELECT, INSERT, UPDATE ON public.intern_work_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.intern_breaks TO authenticated;
GRANT SELECT, UPDATE ON public.intern_modules TO authenticated;
GRANT INSERT ON public.intern_app_usage TO authenticated;
GRANT SELECT, INSERT ON public.intern_submissions TO authenticated;
GRANT SELECT ON public.intern_git_permissions TO authenticated;

GRANT ALL ON public.intern_work_sessions   TO service_role;
GRANT ALL ON public.intern_breaks          TO service_role;
GRANT ALL ON public.intern_modules         TO service_role;
GRANT ALL ON public.intern_app_usage       TO service_role;
GRANT ALL ON public.intern_submissions     TO service_role;
GRANT ALL ON public.intern_git_permissions TO service_role;
GRANT ALL ON public.intern_admin_reports   TO service_role;

-- ============================================================
-- STORAGE BUCKETS for submissions
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('intern-submissions', 'intern-submissions', false)
ON CONFLICT (id) DO NOTHING;

-- Students can upload to their own folder
CREATE POLICY "intern_sub_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'intern-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Students can read their own uploads
CREATE POLICY "intern_sub_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'intern-submissions'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public._is_intern_admin()
    )
  );

-- Admins can read all
CREATE POLICY "intern_sub_admin_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'intern-submissions'
    AND public._is_intern_admin()
  );
