-- ============================================================
-- SKILLUPNOW — PROJECT MODULE SYSTEM
-- v30: Extends internship_projects with project_type/team_size,
--      adds modules, assignments, work sessions, activity logs,
--      and git repository management.
-- Run AFTER internship-schema.sql.
-- ============================================================

-- ── Extend internship_projects with project_type and team_size ──
ALTER TABLE public.internship_projects
  ADD COLUMN IF NOT EXISTS project_type TEXT NOT NULL DEFAULT 'internship'
    CHECK (project_type IN ('available','internship','upcoming')),
  ADD COLUMN IF NOT EXISTS team_size INT NOT NULL DEFAULT 5;

-- ── Project Modules (learning units within a project) ──────────
CREATE TABLE IF NOT EXISTS public.project_modules (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id   UUID NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  module_name  TEXT NOT NULL,
  description  TEXT DEFAULT '',
  deadline     DATE,
  order_num    INT  NOT NULL DEFAULT 0,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  git_branch   TEXT,
  created_by   UUID REFERENCES auth.users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_project_modules_updated_at
  BEFORE UPDATE ON public.project_modules
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── Project Assignments (admin assigns student → module) ────────
CREATE TABLE IF NOT EXISTS public.project_assignments (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id       UUID NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  module_id        UUID REFERENCES public.project_modules(id) ON DELETE SET NULL,
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_by      UUID NOT NULL REFERENCES auth.users(id),
  assigned_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status           TEXT NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active','completed','revoked')),
  notes            TEXT,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(module_id, student_user_id)
);

CREATE TRIGGER trg_project_assignments_updated_at
  BEFORE UPDATE ON public.project_assignments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── Work Sessions (per-session login/logout tracking) ──────────
CREATE TABLE IF NOT EXISTS public.project_work_sessions (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  assignment_id    UUID NOT NULL REFERENCES public.project_assignments(id) ON DELETE CASCADE,
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_start    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  session_end      TIMESTAMPTZ,
  duration_seconds INT,
  device_type      TEXT,
  browser          TEXT,
  os               TEXT,
  ip_address       TEXT,
  user_agent       TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger: auto-compute duration_seconds on session_end update
CREATE OR REPLACE FUNCTION public.trg_compute_session_duration()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.session_end IS NOT NULL AND OLD.session_end IS NULL THEN
    NEW.duration_seconds := EXTRACT(EPOCH FROM (NEW.session_end - NEW.session_start))::INT;
    NEW.is_active := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_session_duration ON public.project_work_sessions;
CREATE TRIGGER trg_session_duration
  BEFORE UPDATE ON public.project_work_sessions
  FOR EACH ROW EXECUTE FUNCTION public.trg_compute_session_duration();

-- ── Activity Logs (fine-grained action tracking) ───────────────
CREATE TABLE IF NOT EXISTS public.project_activity_logs (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id       UUID REFERENCES public.project_work_sessions(id) ON DELETE CASCADE,
  assignment_id    UUID NOT NULL REFERENCES public.project_assignments(id) ON DELETE CASCADE,
  student_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type      TEXT NOT NULL,
  action_data      JSONB DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Git Repositories (one per project) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.project_git_repos (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id       UUID NOT NULL REFERENCES public.internship_projects(id) ON DELETE CASCADE,
  repo_url         TEXT NOT NULL,
  repo_platform    TEXT DEFAULT 'github'
                     CHECK (repo_platform IN ('github','gitlab','bitbucket','other')),
  is_private       BOOLEAN NOT NULL DEFAULT true,
  instructions     TEXT,
  created_by       UUID REFERENCES auth.users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(project_id)
);

CREATE TRIGGER trg_project_git_repos_updated_at
  BEFORE UPDATE ON public.project_git_repos
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── Git Access (per student assignment) ────────────────────────
CREATE TABLE IF NOT EXISTS public.project_git_access (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  assignment_id    UUID NOT NULL REFERENCES public.project_assignments(id) ON DELETE CASCADE,
  repo_id          UUID NOT NULL REFERENCES public.project_git_repos(id) ON DELETE CASCADE,
  github_username  TEXT,
  access_level     TEXT NOT NULL DEFAULT 'read'
                     CHECK (access_level IN ('read','write','admin')),
  granted_by       UUID REFERENCES auth.users(id),
  granted_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at       TIMESTAMPTZ,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(assignment_id)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.project_modules       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_assignments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_work_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_git_repos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_git_access    ENABLE ROW LEVEL SECURITY;

-- project_modules: public read of active, admin full control
DROP POLICY IF EXISTS "pm_read_active" ON public.project_modules;
DROP POLICY IF EXISTS "pm_admin_all"   ON public.project_modules;
CREATE POLICY "pm_read_active" ON public.project_modules
  FOR SELECT USING (is_active = true OR public._is_intern_admin());
CREATE POLICY "pm_admin_all"   ON public.project_modules
  FOR ALL    USING (public._is_intern_admin());

-- project_assignments: student sees own, admin sees all
DROP POLICY IF EXISTS "pa_student_select" ON public.project_assignments;
DROP POLICY IF EXISTS "pa_admin_all"      ON public.project_assignments;
CREATE POLICY "pa_student_select" ON public.project_assignments
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pa_admin_all" ON public.project_assignments
  FOR ALL    USING (public._is_intern_admin());

-- project_work_sessions: student sees/manages own, admin sees all
DROP POLICY IF EXISTS "pws_student_select" ON public.project_work_sessions;
DROP POLICY IF EXISTS "pws_student_insert" ON public.project_work_sessions;
DROP POLICY IF EXISTS "pws_student_update" ON public.project_work_sessions;
DROP POLICY IF EXISTS "pws_admin_all"      ON public.project_work_sessions;
CREATE POLICY "pws_student_select" ON public.project_work_sessions
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pws_student_insert" ON public.project_work_sessions
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "pws_student_update" ON public.project_work_sessions
  FOR UPDATE USING (student_user_id = auth.uid() AND is_active = true);
CREATE POLICY "pws_admin_all" ON public.project_work_sessions
  FOR ALL    USING (public._is_intern_admin());

-- project_activity_logs: student inserts own, admin reads all
DROP POLICY IF EXISTS "pal_student_insert" ON public.project_activity_logs;
DROP POLICY IF EXISTS "pal_student_select" ON public.project_activity_logs;
DROP POLICY IF EXISTS "pal_admin_all"      ON public.project_activity_logs;
CREATE POLICY "pal_student_select" ON public.project_activity_logs
  FOR SELECT USING (student_user_id = auth.uid() OR public._is_intern_admin());
CREATE POLICY "pal_student_insert" ON public.project_activity_logs
  FOR INSERT WITH CHECK (student_user_id = auth.uid());
CREATE POLICY "pal_admin_all" ON public.project_activity_logs
  FOR ALL    USING (public._is_intern_admin());

-- project_git_repos: assigned students see only their project's repo; admin full
DROP POLICY IF EXISTS "pgr_assigned_select" ON public.project_git_repos;
DROP POLICY IF EXISTS "pgr_admin_all"       ON public.project_git_repos;
CREATE POLICY "pgr_assigned_select" ON public.project_git_repos
  FOR SELECT USING (
    public._is_intern_admin() OR
    EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.project_id = project_git_repos.project_id
        AND pa.student_user_id = auth.uid()
        AND pa.status = 'active'
    )
  );
CREATE POLICY "pgr_admin_all" ON public.project_git_repos
  FOR ALL    USING (public._is_intern_admin());

-- project_git_access: student sees own, admin full
DROP POLICY IF EXISTS "pga_student_select" ON public.project_git_access;
DROP POLICY IF EXISTS "pga_admin_all"      ON public.project_git_access;
CREATE POLICY "pga_student_select" ON public.project_git_access
  FOR SELECT USING (
    public._is_intern_admin() OR
    EXISTS (
      SELECT 1 FROM public.project_assignments pa
      WHERE pa.id = project_git_access.assignment_id
        AND pa.student_user_id = auth.uid()
    )
  );
CREATE POLICY "pga_admin_all" ON public.project_git_access
  FOR ALL    USING (public._is_intern_admin());

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_pm_project    ON public.project_modules(project_id);
CREATE INDEX IF NOT EXISTS idx_pa_project    ON public.project_assignments(project_id);
CREATE INDEX IF NOT EXISTS idx_pa_module     ON public.project_assignments(module_id);
CREATE INDEX IF NOT EXISTS idx_pa_student    ON public.project_assignments(student_user_id);
CREATE INDEX IF NOT EXISTS idx_pws_assign    ON public.project_work_sessions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_pws_student   ON public.project_work_sessions(student_user_id);
CREATE INDEX IF NOT EXISTS idx_pws_active    ON public.project_work_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_pal_session   ON public.project_activity_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_pal_assign    ON public.project_activity_logs(assignment_id);
CREATE INDEX IF NOT EXISTS idx_pal_student   ON public.project_activity_logs(student_user_id);
CREATE INDEX IF NOT EXISTS idx_pgr_project   ON public.project_git_repos(project_id);
CREATE INDEX IF NOT EXISTS idx_pga_assign    ON public.project_git_access(assignment_id);
