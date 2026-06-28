-- v49 — Enable Supabase Realtime on all tables used by admin panel,
--        mentor dashboard, student profile, and intern dashboard.
--
-- Supabase requires each table to be explicitly added to the
-- 'supabase_realtime' publication for postgres_changes subscriptions
-- to receive events.  Without this, .on('postgres_changes', ...) calls
-- subscribe successfully but silently receive zero events.
--
-- Run once in the Supabase SQL Editor.  Re-running is safe — the
-- IF NOT EXISTS guard (via DO block) prevents duplicate errors.

-- Helper: idempotent "add table to publication if not already present"
-- Skips views, missing tables, and tables already in the publication.
CREATE OR REPLACE FUNCTION _tmp_add_to_realtime(tbl TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  -- Skip if not a real base table (views, materialized views, etc.)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = tbl AND table_type = 'BASE TABLE'
  ) THEN
    RAISE NOTICE 'public.% is not a base table — skipped', tbl;
    RETURN;
  END IF;

  -- Skip if already in the publication
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = tbl
  ) THEN
    RETURN;
  END IF;

  EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
  RAISE NOTICE 'Added public.% to supabase_realtime', tbl;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not add public.% — %', tbl, SQLERRM;
END;
$$;

-- ═══════════ Core tables ═══════════
SELECT _tmp_add_to_realtime('courses');
SELECT _tmp_add_to_realtime('course_categories');
SELECT _tmp_add_to_realtime('course_pricing');
SELECT _tmp_add_to_realtime('course_batches');
SELECT _tmp_add_to_realtime('course_interests');

-- ═══════════ Users & Mentors ═══════════
SELECT _tmp_add_to_realtime('user_profiles');
SELECT _tmp_add_to_realtime('mentor_profiles');
SELECT _tmp_add_to_realtime('mentor_documents');
SELECT _tmp_add_to_realtime('user_role_assignments');
SELECT _tmp_add_to_realtime('admin_profiles');

-- ═══════════ Enrollments ═══════════
SELECT _tmp_add_to_realtime('enrollments');
SELECT _tmp_add_to_realtime('user_enrollments');

-- ═══════════ Payments & EMI ═══════════
SELECT _tmp_add_to_realtime('payments');
SELECT _tmp_add_to_realtime('payment_schedules');

-- ═══════════ Discounts & Referrals ═══════════
SELECT _tmp_add_to_realtime('discount_campaigns');
SELECT _tmp_add_to_realtime('referral_codes');
SELECT _tmp_add_to_realtime('referral_logs');

-- ═══════════ Reviews & Feedback ═══════════
SELECT _tmp_add_to_realtime('reviews');
SELECT _tmp_add_to_realtime('feedback');

-- ═══════════ Forms & Enquiries ═══════════
SELECT _tmp_add_to_realtime('form_submissions');
SELECT _tmp_add_to_realtime('site_forms');
SELECT _tmp_add_to_realtime('inquiries');
-- contact_enquiries is a VIEW over inquiries — covered by the line above

-- ═══════════ Scheduling & Recordings ═══════════
SELECT _tmp_add_to_realtime('class_sessions');
SELECT _tmp_add_to_realtime('class_attendance');
SELECT _tmp_add_to_realtime('live_recordings');
SELECT _tmp_add_to_realtime('holidays');

-- ═══════════ Notifications & Activity ═══════════
SELECT _tmp_add_to_realtime('notifications');
SELECT _tmp_add_to_realtime('activity_logs');

-- ═══════════ Client Requirements ═══════════
SELECT _tmp_add_to_realtime('project_requirements');

-- ═══════════ Internship tables ═══════════
SELECT _tmp_add_to_realtime('internship_projects');
SELECT _tmp_add_to_realtime('internship_enrollments');
SELECT _tmp_add_to_realtime('internship_applications');
SELECT _tmp_add_to_realtime('intern_daily_reports');
SELECT _tmp_add_to_realtime('intern_attendance');
SELECT _tmp_add_to_realtime('intern_work_sessions');
SELECT _tmp_add_to_realtime('intern_breaks');
SELECT _tmp_add_to_realtime('intern_submissions');
SELECT _tmp_add_to_realtime('intern_git_permissions');
SELECT _tmp_add_to_realtime('intern_session_tasks');
SELECT _tmp_add_to_realtime('intern_program_modules');
SELECT _tmp_add_to_realtime('intern_program_assignments');
SELECT _tmp_add_to_realtime('intern_modules');

-- Clean up temporary function
DROP FUNCTION IF EXISTS _tmp_add_to_realtime(TEXT);
