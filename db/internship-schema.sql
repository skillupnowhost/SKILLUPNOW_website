-- ============================================================
-- SKILLUPNOW — INTERNSHIP TRACKING MODULE
-- Run this AFTER the main schema.sql has been applied.
-- ============================================================

-- ============================================================
-- TABLES
-- ============================================================

-- Internship Projects (defined by admin)
CREATE TABLE IF NOT EXISTS public.internship_projects (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_name         TEXT NOT NULL,
  client_name          TEXT NOT NULL,
  country              TEXT NOT NULL DEFAULT 'India',
  domain               TEXT NOT NULL DEFAULT 'General',
  description          TEXT NOT NULL DEFAULT '',
  detailed_description TEXT DEFAULT '',
  tasks                JSONB DEFAULT '[]'::jsonb,
  tech_stack           TEXT[] DEFAULT '{}',
  learning_outcomes    TEXT[] DEFAULT '{}',
  duration_weeks       INT NOT NULL DEFAULT 4,
  max_students         INT NOT NULL DEFAULT 10,
  is_active            BOOLEAN NOT NULL DEFAULT true,
  thumbnail_url        TEXT,
  created_by           UUID REFERENCES auth.users(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_internship_projects_updated_at
  BEFORE UPDATE ON public.internship_projects
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Student → Project enrollments (one per student; re-apply allowed after rejection)
CREATE TABLE IF NOT EXISTS public.internship_enrollments (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id       UUID NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  approval_status  TEXT NOT NULL DEFAULT 'pending'
                     CHECK (approval_status IN ('pending','approved','rejected')),
  approved_by      UUID REFERENCES auth.users(id),
  approved_at      TIMESTAMPTZ,
  rejection_reason TEXT,
  start_date       DATE,
  end_date         DATE,
  enrolled_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_internship_enrollments_updated_at
  BEFORE UPDATE ON public.internship_enrollments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Daily reports submitted by students
CREATE TABLE IF NOT EXISTS public.internship_daily_reports (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  enrollment_id    UUID NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_date      DATE NOT NULL,
  work_summary     TEXT NOT NULL DEFAULT '',
  tasks_completed  JSONB DEFAULT '[]'::jsonb,
  hours_worked     NUMERIC(4,2) NOT NULL DEFAULT 0
                     CHECK (hours_worked >= 0 AND hours_worked <= 24),
  challenges       TEXT DEFAULT '',
  next_day_plan    TEXT DEFAULT '',
  mood_rating      INT CHECK (mood_rating BETWEEN 1 AND 5),
  report_status    TEXT NOT NULL DEFAULT 'submitted'
                     CHECK (report_status IN ('submitted','reviewed','flagged','approved')),
  admin_notes      TEXT,
  submitted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at      TIMESTAMPTZ,
  reviewed_by      UUID REFERENCES auth.users(id),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(enrollment_id, report_date)
);

CREATE TRIGGER trg_internship_reports_updated_at
  BEFORE UPDATE ON public.internship_daily_reports
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Attendance records (admin-managed; auto-created from report submission)
CREATE TABLE IF NOT EXISTS public.internship_attendance (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  enrollment_id    UUID NOT NULL REFERENCES public.internship_enrollments(id) ON DELETE CASCADE,
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attendance_date  DATE NOT NULL,
  check_in_time    TIME,
  check_out_time   TIME,
  status           TEXT NOT NULL DEFAULT 'absent'
                     CHECK (status IN ('present','absent','late','half_day','holiday','excused')),
  notes            TEXT,
  marked_by        UUID REFERENCES auth.users(id),
  marked_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(enrollment_id, attendance_date)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.internship_projects     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.internship_enrollments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.internship_daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.internship_attendance   ENABLE ROW LEVEL SECURITY;

-- Helper: is admin
CREATE OR REPLACE FUNCTION public._is_intern_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid() AND role IN ('admin','super_admin')
  );
$$;

-- ── internship_projects ──
DROP POLICY IF EXISTS "ip_read_active"  ON public.internship_projects;
DROP POLICY IF EXISTS "ip_admin_all"    ON public.internship_projects;

CREATE POLICY "ip_read_active" ON public.internship_projects
  FOR SELECT USING (is_active = true OR public._is_intern_admin());

CREATE POLICY "ip_admin_all" ON public.internship_projects
  FOR ALL USING (public._is_intern_admin());

-- ── internship_enrollments ──
DROP POLICY IF EXISTS "ie_student_select" ON public.internship_enrollments;
DROP POLICY IF EXISTS "ie_student_insert" ON public.internship_enrollments;
DROP POLICY IF EXISTS "ie_admin_all"      ON public.internship_enrollments;

CREATE POLICY "ie_student_select" ON public.internship_enrollments
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());

CREATE POLICY "ie_student_insert" ON public.internship_enrollments
  FOR INSERT WITH CHECK (student_user_id = auth.uid());

CREATE POLICY "ie_admin_all" ON public.internship_enrollments
  FOR ALL USING (public._is_intern_admin());

-- ── internship_daily_reports ──
DROP POLICY IF EXISTS "idr_student_select" ON public.internship_daily_reports;
DROP POLICY IF EXISTS "idr_student_insert" ON public.internship_daily_reports;
DROP POLICY IF EXISTS "idr_student_update" ON public.internship_daily_reports;
DROP POLICY IF EXISTS "idr_admin_all"      ON public.internship_daily_reports;

CREATE POLICY "idr_student_select" ON public.internship_daily_reports
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());

CREATE POLICY "idr_student_insert" ON public.internship_daily_reports
  FOR INSERT WITH CHECK (student_user_id = auth.uid());

CREATE POLICY "idr_student_update" ON public.internship_daily_reports
  FOR UPDATE USING (student_user_id = auth.uid() AND report_status = 'submitted');

CREATE POLICY "idr_admin_all" ON public.internship_daily_reports
  FOR ALL USING (public._is_intern_admin());

-- ── internship_attendance ──
DROP POLICY IF EXISTS "ia_student_select" ON public.internship_attendance;
DROP POLICY IF EXISTS "ia_admin_all"      ON public.internship_attendance;

CREATE POLICY "ia_student_select" ON public.internship_attendance
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());

CREATE POLICY "ia_admin_all" ON public.internship_attendance
  FOR ALL USING (public._is_intern_admin());

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_ie_student   ON public.internship_enrollments(student_user_id);
CREATE INDEX IF NOT EXISTS idx_ie_project   ON public.internship_enrollments(project_id);
CREATE INDEX IF NOT EXISTS idx_ie_status    ON public.internship_enrollments(approval_status);
CREATE INDEX IF NOT EXISTS idx_idr_enroll   ON public.internship_daily_reports(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_idr_date     ON public.internship_daily_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_idr_student  ON public.internship_daily_reports(student_user_id);
CREATE INDEX IF NOT EXISTS idx_ia_enroll    ON public.internship_attendance(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_ia_date      ON public.internship_attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_ia_student   ON public.internship_attendance(student_user_id);
