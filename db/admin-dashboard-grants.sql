-- ============================================================
-- SKILLUPNOW ADMIN DASHBOARD GRANTS
-- Grants table privileges required by the browser-side admin UI.
-- RLS policies still enforce who can actually read/write rows.
-- Run this after db/schema.sql in the Supabase SQL editor.
-- ============================================================

GRANT USAGE ON SCHEMA public TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.course_categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.courses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.course_pricing TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.course_mentor_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.course_batches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.class_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.live_recordings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.enrollments        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.student_profiles   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.class_attendance   TO authenticated;
GRANT SELECT                          ON TABLE public.user_profiles      TO authenticated;
GRANT SELECT                          ON TABLE public.user_role_assignments TO authenticated;
GRANT SELECT                          ON TABLE public.admin_profiles     TO authenticated;
GRANT SELECT                          ON TABLE public.admin_portal_access TO authenticated;
GRANT SELECT                          ON TABLE public.mentor_profiles    TO authenticated;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
