-- v37: Site-wide review system (Courses / Development / Projects / Internship)
-- Separate from the legacy per-course public.reviews table — this one covers
-- reviews of the platform's software development work, completed projects,
-- and internship experiences, in addition to courses. Public submission,
-- with photo/video attachments, admin moderation before anything goes live.
-- Safe to re-run — uses IF NOT EXISTS / ON CONFLICT / DROP POLICY IF EXISTS.

-- ── Table ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.site_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('courses', 'development', 'projects', 'internship')),
  name TEXT NOT NULL,
  email TEXT,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title TEXT,
  comment TEXT NOT NULL,
  image_urls TEXT[] NOT NULL DEFAULT '{}',
  video_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  admin_note TEXT,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_site_reviews_updated_at ON public.site_reviews;
CREATE TRIGGER trg_site_reviews_updated_at
  BEFORE UPDATE ON public.site_reviews
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_site_reviews_category_status
  ON public.site_reviews (category, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_site_reviews_status_created
  ON public.site_reviews (status, created_at DESC);

-- ── Grants ─────────────────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.site_reviews TO authenticated;
GRANT SELECT ON TABLE public.site_reviews TO anon;
GRANT INSERT ON TABLE public.site_reviews TO anon;

-- ── RLS ────────────────────────────────────────────────────────────────────
ALTER TABLE public.site_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS site_reviews_read_policy ON public.site_reviews;
CREATE POLICY site_reviews_read_policy ON public.site_reviews
  FOR SELECT
  USING (status = 'approved' OR public.is_admin());

-- New submissions always land as pending — callers cannot self-approve or
-- self-feature a review by crafting the insert payload.
DROP POLICY IF EXISTS site_reviews_insert_policy ON public.site_reviews;
CREATE POLICY site_reviews_insert_policy ON public.site_reviews
  FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR (status = 'pending' AND is_featured = FALSE AND reviewed_by IS NULL AND reviewed_at IS NULL)
  );

DROP POLICY IF EXISTS site_reviews_update_policy ON public.site_reviews;
CREATE POLICY site_reviews_update_policy ON public.site_reviews
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS site_reviews_delete_policy ON public.site_reviews;
CREATE POLICY site_reviews_delete_policy ON public.site_reviews
  FOR DELETE
  USING (public.is_admin());

-- ── Storage bucket for review media (images + video clips) ────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'review-media',
  'review-media',
  true,
  104857600, -- 100 MB (covers short video testimonials)
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public review submission is anonymous (no login required to leave a
-- review), so uploads must be allowed from the anon role. Abuse exposure is
-- limited by the size/mime allowlist above and by the fact that nothing is
-- publicly listed until an admin approves the row it belongs to.
DROP POLICY IF EXISTS "review_media_public_upload" ON storage.objects;
DROP POLICY IF EXISTS "review_media_public_read"   ON storage.objects;
DROP POLICY IF EXISTS "review_media_admin_delete"  ON storage.objects;

CREATE POLICY "review_media_public_upload"
  ON storage.objects FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'review-media');

CREATE POLICY "review_media_public_read"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'review-media');

CREATE POLICY "review_media_admin_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'review-media' AND public.is_admin());

-- ============================================================
-- END v37-site-reviews
-- Run this once in the Supabase SQL editor for the project's DB.
-- Requires public.is_admin() and public.handle_updated_at() to already
-- exist (they do — see db/schema.sql).
-- ============================================================
