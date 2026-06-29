-- ============================================================
-- v51: Fix submission storage buckets
-- Creates intern-submissions and project-submissions buckets
-- as PUBLIC so getPublicUrl() links work correctly.
-- Safe to re-run — uses ON CONFLICT.
-- ============================================================

-- ── 1. Create intern-submissions bucket (public) ────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'intern-submissions',
  'intern-submissions',
  true,
  10485760,  -- 10 MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif','application/pdf',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel']
)
ON CONFLICT (id) DO UPDATE
  SET public = true,
      file_size_limit = 10485760,
      allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','image/gif','application/pdf',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel'];

-- ── 2. Create project-submissions bucket (public) ───────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'project-submissions',
  'project-submissions',
  true,
  10485760,  -- 10 MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif','application/pdf',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel']
)
ON CONFLICT (id) DO UPDATE
  SET public = true,
      file_size_limit = 10485760,
      allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','image/gif','application/pdf',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel'];

-- ── 3. Storage policies for intern-submissions ──────────────
-- Drop existing policies if they exist (safe re-run)
DROP POLICY IF EXISTS "intern_sub_upload" ON storage.objects;
DROP POLICY IF EXISTS "intern_sub_read" ON storage.objects;
DROP POLICY IF EXISTS "intern_sub_admin_read" ON storage.objects;
DROP POLICY IF EXISTS "intern_sub_public_read" ON storage.objects;

-- Students can upload to their own folder
CREATE POLICY "intern_sub_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'intern-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public read (bucket is public, but policy still required)
CREATE POLICY "intern_sub_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'intern-submissions');

-- ── 4. Storage policies for project-submissions ─────────────
DROP POLICY IF EXISTS "proj_sub_upload" ON storage.objects;
DROP POLICY IF EXISTS "proj_sub_read" ON storage.objects;
DROP POLICY IF EXISTS "proj_sub_public_read" ON storage.objects;

-- Students can upload to their own folder
CREATE POLICY "proj_sub_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'project-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public read
CREATE POLICY "proj_sub_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'project-submissions');
