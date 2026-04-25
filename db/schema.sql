-- ============================================================
-- SKILLUPNOW - PRODUCTION DATABASE SCHEMA
-- PostgreSQL 15 / Supabase
-- Clean install schema for students, mentors, admins, courses,
-- enrollments, pricing, payments, publishing, access control,
-- mentor operations, and audit/security tracking.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUM TYPES
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'platform_role') THEN
    CREATE TYPE public.platform_role AS ENUM ('student', 'mentor', 'admin', 'super_admin', 'support');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mentor_status') THEN
    CREATE TYPE public.mentor_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'admin_status') THEN
    CREATE TYPE public.admin_status AS ENUM ('active', 'inactive', 'suspended');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'course_status') THEN
    CREATE TYPE public.course_status AS ENUM ('draft', 'review', 'published', 'archived');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'course_visibility') THEN
    CREATE TYPE public.course_visibility AS ENUM ('private', 'public', 'unlisted');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mentor_assignment_role') THEN
    CREATE TYPE public.mentor_assignment_role AS ENUM ('lead', 'assistant', 'reviewer', 'substitute');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lesson_type') THEN
    CREATE TYPE public.lesson_type AS ENUM ('video', 'live_class', 'document', 'quiz', 'assignment', 'recording');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lesson_access_tier') THEN
    CREATE TYPE public.lesson_access_tier AS ENUM ('preview', 'enrolled', 'paid');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pricing_type') THEN
    CREATE TYPE public.pricing_type AS ENUM ('full_payment', 'emi', 'subscription', 'scholarship', 'custom');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'discount_type') THEN
    CREATE TYPE public.discount_type AS ENUM ('percentage', 'flat');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'enrollment_status') THEN
    CREATE TYPE public.enrollment_status AS ENUM ('pending', 'active', 'completed', 'cancelled', 'blocked', 'expired');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
    CREATE TYPE public.payment_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'schedule_status') THEN
    CREATE TYPE public.schedule_status AS ENUM ('pending', 'partial', 'paid', 'overdue', 'waived', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
    CREATE TYPE public.invoice_status AS ENUM ('draft', 'issued', 'paid', 'partially_paid', 'overdue', 'void');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
    CREATE TYPE public.payment_method AS ENUM ('upi', 'card', 'net_banking', 'wallet', 'cash', 'bank_transfer', 'gateway_link');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_gateway') THEN
    CREATE TYPE public.payment_gateway AS ENUM ('razorpay', 'stripe', 'manual', 'cash', 'bank');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'refund_status') THEN
    CREATE TYPE public.refund_status AS ENUM ('requested', 'approved', 'processed', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'class_status') THEN
    CREATE TYPE public.class_status AS ENUM ('scheduled', 'ongoing', 'completed', 'cancelled', 'rescheduled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_status') THEN
    CREATE TYPE public.attendance_status AS ENUM ('present', 'absent', 'late', 'excused');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'access_status') THEN
    CREATE TYPE public.access_status AS ENUM ('pending', 'active', 'restricted', 'revoked', 'expired');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'access_model') THEN
    CREATE TYPE public.access_model AS ENUM ('free', 'full_payment', 'first_installment', 'manual_approval');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activity_actor_type') THEN
    CREATE TYPE public.activity_actor_type AS ENUM ('system', 'student', 'mentor', 'admin', 'anonymous');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ============================================================
-- IDENTITY & ROLE DOMAIN
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  id UUID GENERATED ALWAYS AS (user_id) STORED UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT UNIQUE,
  username TEXT UNIQUE,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
  avatar_url TEXT,
  profile_picture_url TEXT,
  country_code TEXT DEFAULT 'IN',
  state TEXT,
  city TEXT,
  postal_code TEXT,
  address_line_1 TEXT,
  address_line_2 TEXT,
  address TEXT,
  timezone TEXT DEFAULT 'Asia/Kolkata',
  role TEXT NOT NULL DEFAULT 'user'
    CHECK (role IN ('student', 'user', 'mentor', 'admin', 'super_admin', 'support')),
  is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_sign_in_at TIMESTAMPTZ,
  last_password_change_at TIMESTAMPTZ,
  account_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_role_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.platform_role NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_reason TEXT,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS public.student_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
  referral_code TEXT UNIQUE DEFAULT SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8),
  referred_by_user_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
  career_goal TEXT,
  highest_qualification TEXT,
  current_occupation TEXT,
  preferred_learning_mode TEXT,
  marketing_source TEXT,
  signup_notes TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.mentor_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
  mentor_code TEXT UNIQUE,
  designation TEXT,
  bio TEXT,
  qualifications TEXT NOT NULL,
  expertise_areas TEXT[] NOT NULL DEFAULT '{}',
  years_of_experience INT NOT NULL DEFAULT 0 CHECK (years_of_experience >= 0),
  linkedin_url TEXT,
  portfolio_url TEXT,
  photo_url TEXT,
  pan_number TEXT,
  aadhaar_number TEXT,
  bank_account_number TEXT,
  bank_ifsc TEXT,
  bank_name TEXT,
  salary_type TEXT NOT NULL DEFAULT 'per_session' CHECK (salary_type IN ('fixed_monthly', 'per_session', 'revenue_share')),
  salary_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (salary_amount >= 0),
  status public.mentor_status NOT NULL DEFAULT 'pending',
  approved_by_admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  total_students_managed INT NOT NULL DEFAULT 0 CHECK (total_students_managed >= 0),
  total_classes_assigned INT NOT NULL DEFAULT 0 CHECK (total_classes_assigned >= 0),
  average_rating NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK (average_rating >= 0 AND average_rating <= 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
  admin_code TEXT UNIQUE,
  admin_title TEXT,
  department TEXT,
  permissions JSONB NOT NULL DEFAULT jsonb_build_object(
    'users', jsonb_build_object('view', true, 'edit', true, 'delete', false),
    'courses', jsonb_build_object('view', true, 'edit', true, 'publish', true),
    'payments', jsonb_build_object('view', true, 'edit', true, 'refund', false),
    'mentors', jsonb_build_object('view', true, 'approve', false, 'edit', true),
    'reports', jsonb_build_object('view', true, 'export', false)
  ),
  status public.admin_status NOT NULL DEFAULT 'active',
  created_by_admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.auth_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_name TEXT NOT NULL,
  event_result TEXT NOT NULL DEFAULT 'success',
  ip_address INET,
  user_agent TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, full_name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', 'New User'), NEW.email)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_role_assignments (user_id, role, is_primary, is_active, assigned_reason)
  VALUES (NEW.id, 'student', TRUE, TRUE, 'Default role on signup')
  ON CONFLICT (user_id, role) DO NOTHING;

  INSERT INTO public.student_profiles (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.auth_activity_logs (user_id, event_name, metadata)
  VALUES (NEW.id, 'signup', jsonb_build_object('source', 'auth.users trigger'));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

CREATE OR REPLACE FUNCTION public.ensure_role_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'student' THEN
    INSERT INTO public.student_profiles (user_id) VALUES (NEW.user_id) ON CONFLICT (user_id) DO NOTHING;
  ELSIF NEW.role = 'mentor' THEN
    INSERT INTO public.mentor_profiles (user_id, qualifications)
    VALUES (NEW.user_id, 'Pending qualification update')
    ON CONFLICT (user_id) DO NOTHING;
  ELSIF NEW.role IN ('admin', 'super_admin', 'support') THEN
    INSERT INTO public.admin_profiles (user_id) VALUES (NEW.user_id) ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_role_profile ON public.user_role_assignments;
CREATE TRIGGER trg_ensure_role_profile
AFTER INSERT ON public.user_role_assignments
FOR EACH ROW EXECUTE FUNCTION public.ensure_role_profile();

CREATE OR REPLACE FUNCTION public.sync_user_profile_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target_user_id UUID;
BEGIN
  v_target_user_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.user_id
    ELSE NEW.user_id
  END;

  SELECT CASE role
    WHEN 'student' THEN 'user'
    ELSE role::TEXT
  END
  INTO v_role
  FROM public.user_role_assignments
  WHERE user_id = v_target_user_id
    AND is_active = TRUE
  ORDER BY CASE role
    WHEN 'super_admin' THEN 1
    WHEN 'admin' THEN 2
    WHEN 'support' THEN 3
    WHEN 'mentor' THEN 4
    ELSE 5
  END
  LIMIT 1;

  UPDATE public.user_profiles
  SET role = COALESCE(v_role, 'user'),
      updated_at = NOW()
  WHERE user_id = v_target_user_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_profile_role ON public.user_role_assignments;
CREATE TRIGGER trg_sync_user_profile_role
AFTER INSERT OR UPDATE OR DELETE ON public.user_role_assignments
FOR EACH ROW EXECUTE FUNCTION public.sync_user_profile_role();
-- ============================================================
-- CATALOG & PUBLISHING DOMAIN
-- ============================================================
CREATE TABLE IF NOT EXISTS public.course_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_category_id UUID REFERENCES public.course_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  icon_name TEXT,
  color_hex TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_by_admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.course_categories(id) ON DELETE RESTRICT,
  owner_admin_id UUID NOT NULL REFERENCES public.admin_profiles(user_id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  short_description TEXT,
  description TEXT,
  level TEXT NOT NULL DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  language_code TEXT NOT NULL DEFAULT 'en',
  duration_days INT CHECK (duration_days IS NULL OR duration_days > 0),
  duration_hours INT CHECK (duration_hours IS NULL OR duration_hours > 0),
  total_lessons INT NOT NULL DEFAULT 0 CHECK (total_lessons >= 0),
  total_live_classes INT NOT NULL DEFAULT 0 CHECK (total_live_classes >= 0),
  course_status public.course_status NOT NULL DEFAULT 'draft',
  visibility public.course_visibility NOT NULL DEFAULT 'private',
  requires_approval BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  published_at TIMESTAMPTZ,
  thumbnail_url TEXT,
  promo_video_url TEXT,
  syllabus_overview JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  pricing_name TEXT NOT NULL,
  pricing_type public.pricing_type NOT NULL DEFAULT 'full_payment',
  currency_code TEXT NOT NULL DEFAULT 'INR',
  list_price NUMERIC(12,2) NOT NULL CHECK (list_price >= 0),
  sale_price NUMERIC(12,2) CHECK (sale_price IS NULL OR sale_price >= 0),
  registration_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (registration_fee >= 0),
  due_days_from_enrollment INT CHECK (due_days_from_enrollment IS NULL OR due_days_from_enrollment >= 0),
  access_duration_days INT CHECK (access_duration_days IS NULL OR access_duration_days > 0),
  emi_installments INT CHECK (emi_installments IS NULL OR emi_installments > 0),
  late_fee_per_day NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (late_fee_per_day >= 0),
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ,
  created_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (sale_price IS NULL OR sale_price <= list_price),
  CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE IF NOT EXISTS public.course_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  discount_code TEXT,
  discount_name TEXT NOT NULL,
  discount_type public.discount_type NOT NULL,
  discount_value NUMERIC(12,2) NOT NULL CHECK (discount_value > 0),
  max_discount_amount NUMERIC(12,2),
  max_redemptions INT,
  redemptions_used INT NOT NULL DEFAULT 0 CHECK (redemptions_used >= 0),
  starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (course_id, discount_code),
  CHECK (max_discount_amount IS NULL OR max_discount_amount >= 0),
  CHECK (max_redemptions IS NULL OR max_redemptions > 0),
  CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS public.course_access_policies (
  course_id UUID PRIMARY KEY REFERENCES public.courses(id) ON DELETE CASCADE,
  access_model public.access_model NOT NULL DEFAULT 'full_payment',
  allow_preview BOOLEAN NOT NULL DEFAULT TRUE,
  require_payment_clearance BOOLEAN NOT NULL DEFAULT TRUE,
  grace_days_after_due INT NOT NULL DEFAULT 0 CHECK (grace_days_after_due >= 0),
  max_concurrent_sessions INT NOT NULL DEFAULT 1 CHECK (max_concurrent_sessions >= 1),
  session_ttl_minutes INT NOT NULL DEFAULT 120 CHECK (session_ttl_minutes >= 5),
  require_device_fingerprint BOOLEAN NOT NULL DEFAULT TRUE,
  allow_downloads BOOLEAN NOT NULL DEFAULT FALSE,
  watermark_template TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_mentor_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  mentor_user_id UUID NOT NULL REFERENCES public.mentor_profiles(user_id) ON DELETE RESTRICT,
  assigned_by_admin_id UUID NOT NULL REFERENCES public.admin_profiles(user_id) ON DELETE RESTRICT,
  assignment_role public.mentor_assignment_role NOT NULL DEFAULT 'lead',
  starts_on DATE,
  ends_on DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (course_id, mentor_user_id, assignment_role)
);

CREATE TABLE IF NOT EXISTS public.course_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  batch_code TEXT NOT NULL UNIQUE,
  batch_name TEXT NOT NULL,
  primary_mentor_user_id UUID REFERENCES public.mentor_profiles(user_id) ON DELETE SET NULL,
  max_students INT NOT NULL DEFAULT 30 CHECK (max_students > 0),
  current_student_count INT NOT NULL DEFAULT 0 CHECK (current_student_count >= 0),
  starts_on DATE,
  ends_on DATE,
  enrollment_open_at TIMESTAMPTZ,
  enrollment_close_at TIMESTAMPTZ,
  schedule_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_publications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  version_number INT NOT NULL,
  publication_notes TEXT,
  published_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_live BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (course_id, version_number)
);

CREATE TABLE IF NOT EXISTS public.course_modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  module_title TEXT NOT NULL,
  module_description TEXT,
  module_order INT NOT NULL CHECK (module_order > 0),
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (course_id, module_order)
);

CREATE TABLE IF NOT EXISTS public.course_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  module_id UUID NOT NULL REFERENCES public.course_modules(id) ON DELETE CASCADE,
  lesson_title TEXT NOT NULL,
  lesson_description TEXT,
  lesson_type public.lesson_type NOT NULL,
  lesson_order INT NOT NULL CHECK (lesson_order > 0),
  access_tier public.lesson_access_tier NOT NULL DEFAULT 'paid',
  release_at TIMESTAMPTZ,
  estimated_duration_minutes INT CHECK (estimated_duration_minutes IS NULL OR estimated_duration_minutes > 0),
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (module_id, lesson_order)
);

CREATE TABLE IF NOT EXISTS public.lesson_media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  asset_type TEXT NOT NULL CHECK (asset_type IN ('video', 'document', 'subtitle', 'thumbnail', 'recording')),
  provider_name TEXT NOT NULL DEFAULT 'supabase_storage',
  storage_bucket TEXT,
  storage_path TEXT,
  playback_url TEXT,
  duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  file_size_bytes BIGINT CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
  mime_type TEXT,
  drm_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- ============================================================
-- ENROLLMENT, BILLING & PAYMENT DOMAIN
-- ============================================================
CREATE TABLE IF NOT EXISTS public.enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_user_id UUID NOT NULL REFERENCES public.student_profiles(user_id) ON DELETE RESTRICT,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
  batch_id UUID REFERENCES public.course_batches(id) ON DELETE SET NULL,
  pricing_id UUID NOT NULL REFERENCES public.course_pricing(id) ON DELETE RESTRICT,
  enrolled_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  enrollment_status public.enrollment_status NOT NULL DEFAULT 'pending',
  access_status public.access_status NOT NULL DEFAULT 'pending',
  list_price NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (list_price >= 0),
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  net_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (net_amount >= 0),
  paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  due_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (due_amount >= 0),
  first_payment_due_at TIMESTAMPTZ,
  final_payment_due_at TIMESTAMPTZ,
  access_start_at TIMESTAMPTZ,
  access_end_at TIMESTAMPTZ,
  activated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  last_accessed_at TIMESTAMPTZ,
  progress_percentage NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (student_user_id, course_id),
  CHECK (access_end_at IS NULL OR access_start_at IS NULL OR access_end_at > access_start_at)
);

CREATE TABLE IF NOT EXISTS public.enrollment_discount_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  discount_id UUID REFERENCES public.course_discounts(id) ON DELETE SET NULL,
  discount_code TEXT,
  discount_type public.discount_type NOT NULL,
  discount_value NUMERIC(12,2) NOT NULL CHECK (discount_value > 0),
  applied_amount NUMERIC(12,2) NOT NULL CHECK (applied_amount >= 0),
  approved_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL UNIQUE DEFAULT ('INV-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8))),
  invoice_status public.invoice_status NOT NULL DEFAULT 'draft',
  issued_at TIMESTAMPTZ,
  due_at TIMESTAMPTZ,
  subtotal_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal_amount >= 0),
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
  installment_number INT NOT NULL CHECK (installment_number > 0),
  title TEXT NOT NULL,
  due_at TIMESTAMPTZ NOT NULL,
  amount_due NUMERIC(12,2) NOT NULL CHECK (amount_due > 0),
  amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
  late_fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (late_fee_amount >= 0),
  schedule_status public.schedule_status NOT NULL DEFAULT 'pending',
  is_access_blocking BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (enrollment_id, installment_number)
);

CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_user_id UUID NOT NULL REFERENCES public.student_profiles(user_id) ON DELETE RESTRICT,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
  payment_schedule_id UUID REFERENCES public.payment_schedules(id) ON DELETE SET NULL,
  payment_method public.payment_method NOT NULL,
  payment_gateway public.payment_gateway NOT NULL DEFAULT 'razorpay',
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  currency_code TEXT NOT NULL DEFAULT 'INR',
  transaction_reference TEXT UNIQUE,
  gateway_order_id TEXT,
  gateway_payment_id TEXT,
  gateway_signature TEXT,
  payment_status public.payment_status NOT NULL DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  failure_reason TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  payment_schedule_id UUID REFERENCES public.payment_schedules(id) ON DELETE SET NULL,
  invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
  allocated_amount NUMERIC(12,2) NOT NULL CHECK (allocated_amount > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (payment_id, payment_schedule_id)
);

CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  refund_amount NUMERIC(12,2) NOT NULL CHECK (refund_amount > 0),
  refund_status public.refund_status NOT NULL DEFAULT 'requested',
  requested_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  reason TEXT
);

-- ============================================================
-- CLASSROOM, ACCESS CONTROL & TRACKING DOMAIN
-- ============================================================
CREATE TABLE IF NOT EXISTS public.class_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES public.course_batches(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  mentor_user_id UUID NOT NULL REFERENCES public.mentor_profiles(user_id) ON DELETE RESTRICT,
  lesson_id UUID REFERENCES public.course_lessons(id) ON DELETE SET NULL,
  session_title TEXT NOT NULL,
  scheduled_start_at TIMESTAMPTZ NOT NULL,
  scheduled_end_at TIMESTAMPTZ NOT NULL,
  meeting_url TEXT,
  recording_asset_id UUID REFERENCES public.lesson_media_assets(id) ON DELETE SET NULL,
  session_status public.class_status NOT NULL DEFAULT 'scheduled',
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (scheduled_end_at > scheduled_start_at)
);

CREATE TABLE IF NOT EXISTS public.class_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_session_id UUID NOT NULL REFERENCES public.class_sessions(id) ON DELETE CASCADE,
  student_user_id UUID NOT NULL REFERENCES public.student_profiles(user_id) ON DELETE CASCADE,
  attendance_status public.attendance_status NOT NULL DEFAULT 'absent',
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  duration_minutes INT CHECK (duration_minutes IS NULL OR duration_minutes >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (class_session_id, student_user_id)
);

CREATE TABLE IF NOT EXISTS public.course_access_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_user_id UUID REFERENCES public.student_profiles(user_id) ON DELETE SET NULL,
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  lesson_id UUID REFERENCES public.course_lessons(id) ON DELETE SET NULL,
  enrollment_id UUID REFERENCES public.enrollments(id) ON DELETE SET NULL,
  action_name TEXT NOT NULL,
  action_result TEXT NOT NULL DEFAULT 'success',
  ip_address INET,
  user_agent TEXT,
  device_fingerprint TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.video_access_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_user_id UUID NOT NULL REFERENCES public.student_profiles(user_id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  access_token_hash TEXT NOT NULL UNIQUE,
  device_fingerprint TEXT,
  ip_address INET,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  revocation_reason TEXT,
  playback_started_at TIMESTAMPTZ,
  playback_ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at > started_at)
);

CREATE TABLE IF NOT EXISTS public.mentor_performance_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id UUID NOT NULL REFERENCES public.mentor_profiles(user_id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  assigned_course_count INT NOT NULL DEFAULT 0 CHECK (assigned_course_count >= 0),
  assigned_batch_count INT NOT NULL DEFAULT 0 CHECK (assigned_batch_count >= 0),
  active_student_count INT NOT NULL DEFAULT 0 CHECK (active_student_count >= 0),
  completed_class_count INT NOT NULL DEFAULT 0 CHECK (completed_class_count >= 0),
  average_attendance_pct NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (average_attendance_pct >= 0 AND average_attendance_pct <= 100),
  average_rating NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK (average_rating >= 0 AND average_rating <= 5),
  performance_notes TEXT,
  generated_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (period_end >= period_start)
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_type public.activity_actor_type NOT NULL DEFAULT 'system',
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  action_name TEXT NOT NULL,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ADMIN, FORMS, FEEDBACK & OPERATIONS DOMAIN
-- ============================================================
CREATE TABLE IF NOT EXISTS public.admin_portal_access (
  user_id UUID PRIMARY KEY REFERENCES public.admin_profiles(user_id) ON DELETE CASCADE,
  authorized_email TEXT NOT NULL UNIQUE,
  secret_key_hash TEXT NOT NULL,
  portal_status TEXT NOT NULL DEFAULT 'active'
    CHECK (portal_status IN ('active', 'disabled', 'locked')),
  otp_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  otp_verified_until TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,
  last_failed_login_at TIMESTAMPTZ,
  failed_attempt_count INT NOT NULL DEFAULT 0 CHECK (failed_attempt_count >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_login_otp_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.admin_profiles(user_id) ON DELETE CASCADE,
  otp_hash TEXT NOT NULL,
  otp_channel TEXT NOT NULL DEFAULT 'email'
    CHECK (otp_channel IN ('email')),
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  consumed_at TIMESTAMPTZ,
  attempt_count INT NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts INT NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at > issued_at)
);

CREATE TABLE IF NOT EXISTS public.signup_email_otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  otp_hash TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  consumed_at TIMESTAMPTZ,
  attempt_count INT NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts INT NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at > issued_at)
);

CREATE TABLE IF NOT EXISTS public.sms_verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  purpose TEXT NOT NULL DEFAULT 'mentor_signup'
    CHECK (purpose IN ('mentor_signup', 'phone_verification', 'meeting_access')),
  otp_hash TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  consumed_at TIMESTAMPTZ,
  attempt_count INT NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts INT NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
  provider_name TEXT,
  provider_reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at > issued_at)
);

CREATE TABLE IF NOT EXISTS public.mentor_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id UUID NOT NULL REFERENCES public.mentor_profiles(user_id) ON DELETE CASCADE,
  document_type TEXT NOT NULL
    CHECK (document_type IN ('certification', 'profile_photo', 'id_proof', 'resume', 'experience_letter', 'other')),
  file_name TEXT,
  storage_bucket TEXT,
  storage_path TEXT,
  public_url TEXT,
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'approved', 'rejected')),
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at TIMESTAMPTZ,
  verified_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  review_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.form_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_type TEXT NOT NULL
    CHECK (form_type IN ('registration', 'feedback', 'emi', 'mentor_signup', 'contact', 'complaint', 'custom')),
  form_key TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  submitted_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  title TEXT,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'received', 'in_review', 'approved', 'rejected', 'resolved', 'archived')),
  form_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  submission_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  admin_notes TEXT,
  reviewed_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  course_title TEXT,
  mentor_user_id UUID REFERENCES public.mentor_profiles(user_id) ON DELETE SET NULL,
  feedback_type TEXT NOT NULL DEFAULT 'general'
    CHECK (feedback_type IN ('general', 'course', 'mentor', 'website', 'payment')),
  full_name TEXT,
  email TEXT,
  phone_number TEXT,
  rating INT CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'reviewed', 'resolved', 'archived')),
  reviewed_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  enrollment_id UUID REFERENCES public.enrollments(id) ON DELETE SET NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title TEXT,
  comment TEXT NOT NULL,
  is_approved BOOLEAN NOT NULL DEFAULT FALSE,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  admin_reply TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, course_id)
);

CREATE TABLE IF NOT EXISTS public.inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  subject TEXT NOT NULL,
  inquiry_details TEXT NOT NULL,
  inquiry_type TEXT NOT NULL DEFAULT 'general'
    CHECK (inquiry_type IN ('general', 'course', 'payment', 'technical', 'admission', 'complaint', 'other')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  priority TEXT NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  source TEXT NOT NULL DEFAULT 'website'
    CHECK (source IN ('website', 'phone', 'email', 'walk_in', 'referral', 'social')),
  assigned_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submitted_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  category TEXT NOT NULL
    CHECK (category IN ('course', 'mentor', 'payment', 'technical', 'schedule', 'content', 'other')),
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'rejected')),
  resolution_notes TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.live_recordings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  batch_id UUID REFERENCES public.course_batches(id) ON DELETE SET NULL,
  class_session_id UUID REFERENCES public.class_sessions(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  provider_name TEXT NOT NULL DEFAULT 'google_drive'
    CHECK (provider_name IN ('google_drive', 'youtube', 'vimeo', 'other')),
  external_url TEXT NOT NULL,
  access_level TEXT NOT NULL DEFAULT 'paid'
    CHECK (access_level IN ('public', 'enrolled', 'paid')),
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  published_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.meeting_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  mentor_user_id UUID REFERENCES public.mentor_profiles(user_id) ON DELETE SET NULL,
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  meeting_type TEXT NOT NULL DEFAULT 'counselling'
    CHECK (meeting_type IN ('counselling', 'doubt_session', 'mentor_call', 'sales_call', 'webinar')),
  title TEXT NOT NULL,
  requested_start_at TIMESTAMPTZ NOT NULL,
  requested_end_at TIMESTAMPTZ,
  google_calendar_event_id TEXT,
  meeting_url TEXT,
  status TEXT NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'approved', 'scheduled', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (requested_end_at IS NULL OR requested_end_at > requested_start_at)
);

CREATE TABLE IF NOT EXISTS public.mentor_salary_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id UUID NOT NULL REFERENCES public.mentor_profiles(user_id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  gross_amount NUMERIC(12,2) NOT NULL CHECK (gross_amount >= 0),
  bonus_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (bonus_amount >= 0),
  deduction_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deduction_amount >= 0),
  net_amount NUMERIC(12,2) NOT NULL CHECK (net_amount >= 0),
  payment_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (payment_status IN ('pending', 'processed', 'failed', 'cancelled')),
  processed_at TIMESTAMPTZ,
  processed_by_admin_id UUID REFERENCES public.admin_profiles(user_id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (period_end >= period_start)
);

CREATE OR REPLACE VIEW public.contact_enquiries AS
SELECT *
FROM public.inquiries;
CREATE OR REPLACE FUNCTION public.protect_append_only_tables()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'This table is append-only';
END;
$$;

DROP TRIGGER IF EXISTS trg_no_update_activity_logs ON public.activity_logs;
DROP TRIGGER IF EXISTS trg_no_delete_activity_logs ON public.activity_logs;
CREATE TRIGGER trg_no_update_activity_logs BEFORE UPDATE ON public.activity_logs FOR EACH ROW EXECUTE FUNCTION public.protect_append_only_tables();
CREATE TRIGGER trg_no_delete_activity_logs BEFORE DELETE ON public.activity_logs FOR EACH ROW EXECUTE FUNCTION public.protect_append_only_tables();

DROP TRIGGER IF EXISTS trg_no_update_course_access_logs ON public.course_access_logs;
DROP TRIGGER IF EXISTS trg_no_delete_course_access_logs ON public.course_access_logs;
CREATE TRIGGER trg_no_update_course_access_logs BEFORE UPDATE ON public.course_access_logs FOR EACH ROW EXECUTE FUNCTION public.protect_append_only_tables();
CREATE TRIGGER trg_no_delete_course_access_logs BEFORE DELETE ON public.course_access_logs FOR EACH ROW EXECUTE FUNCTION public.protect_append_only_tables();

-- ============================================================
-- BUSINESS LOGIC FUNCTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION public.has_admin_permission(p_section TEXT, p_action TEXT DEFAULT 'view')
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE((
    SELECT (permissions -> p_section ->> p_action)::BOOLEAN
    FROM public.admin_profiles
    WHERE user_id = auth.uid()
      AND status = 'active'
  ), FALSE);
$$;

CREATE OR REPLACE FUNCTION public.current_actor_type()
RETURNS public.activity_actor_type
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT CASE
    WHEN auth.uid() IS NULL THEN 'anonymous'::public.activity_actor_type
    WHEN EXISTS (SELECT 1 FROM public.user_role_assignments WHERE user_id = auth.uid() AND role IN ('super_admin', 'admin', 'support') AND is_active = TRUE) THEN 'admin'::public.activity_actor_type
    WHEN EXISTS (SELECT 1 FROM public.user_role_assignments WHERE user_id = auth.uid() AND role = 'mentor' AND is_active = TRUE) THEN 'mentor'::public.activity_actor_type
    ELSE 'student'::public.activity_actor_type
  END;
$$;

CREATE OR REPLACE FUNCTION public.has_role(check_role public.platform_role, check_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_role_assignments
    WHERE user_id = check_user_id AND role = check_role AND is_active = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin(check_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_role_assignments
    WHERE user_id = check_user_id AND role IN ('admin', 'super_admin', 'support') AND is_active = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin(check_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_role_assignments
    WHERE user_id = check_user_id AND role = 'super_admin' AND is_active = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.is_approved_mentor(check_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mentor_profiles
    WHERE user_id = check_user_id AND status = 'approved'
  );
$$;

CREATE OR REPLACE FUNCTION public.request_signup_email_otp(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp TEXT;
BEGIN
  IF p_email IS NULL OR length(trim(p_email)) = 0 THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  DELETE FROM public.signup_email_otps
  WHERE email = lower(trim(p_email))
    AND consumed_at IS NULL
    AND verified_at IS NULL;

  v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

  INSERT INTO public.signup_email_otps (
    email,
    otp_hash,
    expires_at
  ) VALUES (
    lower(trim(p_email)),
    encode(digest(v_otp, 'sha256'), 'hex'),
    NOW() + INTERVAL '10 minutes'
  );

  RETURN jsonb_build_object(
    'email', lower(trim(p_email)),
    'otp', v_otp,
    'expires_in_seconds', 600
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_signup_email_otp(p_email TEXT, p_otp TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.signup_email_otps%ROWTYPE;
BEGIN
  SELECT *
  INTO v_row
  FROM public.signup_email_otps
  WHERE email = lower(trim(p_email))
    AND consumed_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('verified', FALSE, 'message', 'No active OTP found');
  END IF;

  IF v_row.expires_at < NOW() THEN
    UPDATE public.signup_email_otps
    SET consumed_at = NOW()
    WHERE id = v_row.id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'OTP expired');
  END IF;

  IF v_row.attempt_count >= v_row.max_attempts THEN
    UPDATE public.signup_email_otps
    SET consumed_at = NOW()
    WHERE id = v_row.id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'Too many attempts');
  END IF;

  IF encode(digest(p_otp, 'sha256'), 'hex') <> v_row.otp_hash THEN
    UPDATE public.signup_email_otps
    SET attempt_count = attempt_count + 1
    WHERE id = v_row.id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'Invalid OTP');
  END IF;

  UPDATE public.signup_email_otps
  SET verified_at = NOW(),
      consumed_at = NOW()
  WHERE id = v_row.id;

  RETURN jsonb_build_object('verified', TRUE, 'message', 'OTP verified');
END;
$$;

CREATE OR REPLACE FUNCTION public.request_sms_verification_otp(
  p_phone TEXT,
  p_purpose TEXT DEFAULT 'mentor_signup',
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp TEXT;
BEGIN
  IF p_phone IS NULL OR length(trim(p_phone)) < 8 THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

  INSERT INTO public.sms_verification_requests (
    user_id,
    phone,
    purpose,
    otp_hash,
    expires_at
  ) VALUES (
    p_user_id,
    trim(p_phone),
    COALESCE(p_purpose, 'mentor_signup'),
    encode(digest(v_otp, 'sha256'), 'hex'),
    NOW() + INTERVAL '10 minutes'
  );

  RETURN jsonb_build_object(
    'phone', trim(p_phone),
    'otp', v_otp,
    'expires_in_seconds', 600
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_sms_verification_otp(
  p_phone TEXT,
  p_otp TEXT,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.sms_verification_requests%ROWTYPE;
BEGIN
  SELECT *
  INTO v_row
  FROM public.sms_verification_requests
  WHERE phone = trim(p_phone)
    AND (user_id = p_user_id OR p_user_id IS NULL)
    AND consumed_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('verified', FALSE, 'message', 'No active SMS OTP found');
  END IF;

  IF v_row.expires_at < NOW() THEN
    UPDATE public.sms_verification_requests SET consumed_at = NOW() WHERE id = v_row.id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'OTP expired');
  END IF;

  IF encode(digest(p_otp, 'sha256'), 'hex') <> v_row.otp_hash THEN
    UPDATE public.sms_verification_requests
    SET attempt_count = attempt_count + 1
    WHERE id = v_row.id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'Invalid OTP');
  END IF;

  UPDATE public.sms_verification_requests
  SET verified_at = NOW(),
      consumed_at = NOW()
  WHERE id = v_row.id;

  IF p_user_id IS NOT NULL THEN
    UPDATE public.user_profiles
    SET is_phone_verified = TRUE,
        updated_at = NOW()
    WHERE user_id = p_user_id;
  END IF;

  RETURN jsonb_build_object('verified', TRUE, 'message', 'Phone verified');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_admin_auth_context()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email TEXT;
  v_admin_row RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('is_admin', FALSE, 'otp_verified', FALSE);
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  SELECT
    ura.role,
    ap.permissions,
    apa.otp_enabled,
    apa.otp_verified_until,
    apa.last_login_at,
    apa.authorized_email,
    apa.portal_status
  INTO v_admin_row
  FROM public.user_role_assignments ura
  JOIN public.admin_profiles ap ON ap.user_id = ura.user_id
  LEFT JOIN public.admin_portal_access apa ON apa.user_id = ura.user_id
  WHERE ura.user_id = v_user_id
    AND ura.role IN ('admin', 'super_admin', 'support')
    AND ura.is_active = TRUE
    AND ap.status = 'active'
  ORDER BY CASE ura.role WHEN 'super_admin' THEN 1 WHEN 'admin' THEN 2 ELSE 3 END
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('is_admin', FALSE, 'otp_verified', FALSE);
  END IF;

  RETURN jsonb_build_object(
    'is_admin', TRUE,
    'role', v_admin_row.role,
    'permissions', COALESCE(v_admin_row.permissions, '{}'::jsonb),
    'otp_enabled', COALESCE(v_admin_row.otp_enabled, TRUE),
    'otp_verified', COALESCE(v_admin_row.otp_verified_until > NOW(), FALSE),
    'last_login_at', v_admin_row.last_login_at,
    'authorized_email', v_admin_row.authorized_email,
    'email_matches', COALESCE(lower(v_admin_row.authorized_email) = lower(v_email), FALSE),
    'portal_status', COALESCE(v_admin_row.portal_status, 'active')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_admin_portal_secret(p_secret_key TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_hash TEXT;
BEGIN
  IF v_user_id IS NULL OR p_secret_key IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT secret_key_hash
  INTO v_hash
  FROM public.admin_portal_access
  WHERE user_id = v_user_id
    AND portal_status = 'active';

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  RETURN encode(digest(p_secret_key, 'sha256'), 'hex') = v_hash;
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_admin_login_otp()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email TEXT;
  v_access public.admin_portal_access%ROWTYPE;
  v_otp TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_access
  FROM public.admin_portal_access
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin portal access is not configured';
  END IF;

  IF v_access.portal_status <> 'active' THEN
    RAISE EXCEPTION 'Admin portal access is disabled';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  IF lower(COALESCE(v_email, '')) <> lower(v_access.authorized_email) THEN
    RAISE EXCEPTION 'Admin email is not authorized for this portal';
  END IF;

  v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

  UPDATE public.admin_login_otp_challenges
  SET consumed_at = NOW()
  WHERE user_id = v_user_id
    AND consumed_at IS NULL
    AND verified_at IS NULL;

  INSERT INTO public.admin_login_otp_challenges (
    user_id,
    otp_hash,
    expires_at,
    metadata
  ) VALUES (
    v_user_id,
    encode(digest(v_otp, 'sha256'), 'hex'),
    NOW() + INTERVAL '10 minutes',
    jsonb_build_object('purpose', 'admin_login')
  );

  INSERT INTO public.auth_activity_logs (user_id, event_name, metadata)
  VALUES (v_user_id, 'admin_login_otp_issued', jsonb_build_object('email', v_email));

  RETURN jsonb_build_object(
    'email', v_email,
    'otp', v_otp,
    'expires_in_seconds', 600
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_admin_login_otp(p_otp TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row public.admin_login_otp_challenges%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('verified', FALSE, 'message', 'Authentication required');
  END IF;

  SELECT *
  INTO v_row
  FROM public.admin_login_otp_challenges
  WHERE user_id = v_user_id
    AND consumed_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('verified', FALSE, 'message', 'No active admin OTP found');
  END IF;

  IF v_row.expires_at < NOW() THEN
    UPDATE public.admin_login_otp_challenges SET consumed_at = NOW() WHERE id = v_row.id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'OTP expired');
  END IF;

  IF v_row.attempt_count >= v_row.max_attempts THEN
    UPDATE public.admin_login_otp_challenges SET consumed_at = NOW() WHERE id = v_row.id;
    UPDATE public.admin_portal_access
    SET portal_status = 'locked',
        last_failed_login_at = NOW(),
        failed_attempt_count = failed_attempt_count + 1,
        updated_at = NOW()
    WHERE user_id = v_user_id;
    RETURN jsonb_build_object('verified', FALSE, 'message', 'Too many invalid attempts');
  END IF;

  IF encode(digest(p_otp, 'sha256'), 'hex') <> v_row.otp_hash THEN
    UPDATE public.admin_login_otp_challenges
    SET attempt_count = attempt_count + 1
    WHERE id = v_row.id;

    UPDATE public.admin_portal_access
    SET last_failed_login_at = NOW(),
        failed_attempt_count = failed_attempt_count + 1,
        updated_at = NOW()
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object('verified', FALSE, 'message', 'Invalid OTP');
  END IF;

  UPDATE public.admin_login_otp_challenges
  SET verified_at = NOW(),
      consumed_at = NOW()
  WHERE id = v_row.id;

  UPDATE public.admin_portal_access
  SET otp_verified_until = NOW() + INTERVAL '8 hours',
      last_login_at = NOW(),
      failed_attempt_count = 0,
      portal_status = 'active',
      updated_at = NOW()
  WHERE user_id = v_user_id;

  INSERT INTO public.auth_activity_logs (user_id, event_name, metadata)
  VALUES (v_user_id, 'admin_login_verified', jsonb_build_object('method', 'otp'));

  RETURN jsonb_build_object('verified', TRUE, 'message', 'Admin access granted');
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_batch_student_count(p_batch_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_batch_id IS NULL THEN RETURN; END IF;

  UPDATE public.course_batches b
  SET current_student_count = COALESCE((
    SELECT COUNT(*)
    FROM public.enrollments e
    WHERE e.batch_id = b.id AND e.enrollment_status IN ('pending', 'active', 'completed')
  ), 0), updated_at = NOW()
  WHERE b.id = p_batch_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_mentor_counters(p_mentor_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_mentor_user_id IS NULL THEN RETURN; END IF;

  UPDATE public.mentor_profiles m
  SET total_classes_assigned = COALESCE((
        SELECT COUNT(*) FROM public.class_sessions cs WHERE cs.mentor_user_id = p_mentor_user_id
      ), 0),
      total_students_managed = COALESCE((
        SELECT COUNT(DISTINCT e.student_user_id)
        FROM public.course_batches b
        JOIN public.enrollments e ON e.batch_id = b.id
        WHERE b.primary_mentor_user_id = p_mentor_user_id
          AND e.enrollment_status IN ('pending', 'active', 'completed')
      ), 0),
      updated_at = NOW()
  WHERE m.user_id = p_mentor_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_enrollment_state(p_enrollment_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_course_id UUID;
  v_paid NUMERIC(12,2);
  v_grace_days INT;
  v_access_model public.access_model;
  v_has_overdue_blocking BOOLEAN;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  SELECT e.course_id INTO v_course_id
  FROM public.enrollments e
  WHERE e.id = p_enrollment_id;

  IF NOT FOUND THEN RETURN; END IF;

  SELECT COALESCE(SUM(amount), 0)
  INTO v_paid
  FROM public.payments
  WHERE enrollment_id = p_enrollment_id AND payment_status = 'completed';

  SELECT ap.access_model, ap.grace_days_after_due
  INTO v_access_model, v_grace_days
  FROM public.course_access_policies ap
  WHERE ap.course_id = v_course_id;

  v_grace_days := COALESCE(v_grace_days, 0);
  v_access_model := COALESCE(v_access_model, 'full_payment');

  SELECT EXISTS (
    SELECT 1
    FROM public.payment_schedules ps
    WHERE ps.enrollment_id = p_enrollment_id
      AND ps.is_access_blocking = TRUE
      AND ps.schedule_status = 'overdue'
      AND ps.due_at < (v_now - make_interval(days => v_grace_days))
  ) INTO v_has_overdue_blocking;

  UPDATE public.enrollments e
  SET paid_amount = v_paid,
      due_amount = GREATEST(e.net_amount - v_paid, 0),
      access_status = CASE
        WHEN e.enrollment_status IN ('cancelled', 'blocked') THEN 'revoked'::public.access_status
        WHEN e.enrollment_status = 'expired' THEN 'expired'::public.access_status
        WHEN v_has_overdue_blocking THEN 'restricted'::public.access_status
        WHEN v_access_model = 'free' THEN 'active'::public.access_status
        WHEN v_access_model = 'full_payment' AND v_paid >= e.net_amount THEN 'active'::public.access_status
        WHEN v_access_model = 'first_installment' AND v_paid > 0 THEN 'active'::public.access_status
        ELSE 'pending'::public.access_status
      END,
      activated_at = CASE
        WHEN activated_at IS NULL AND (
          v_access_model = 'free' OR
          (v_access_model = 'full_payment' AND v_paid >= e.net_amount) OR
          (v_access_model = 'first_installment' AND v_paid > 0)
        ) THEN v_now
        ELSE activated_at
      END,
      updated_at = v_now
  WHERE e.id = p_enrollment_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_payment_schedule_state()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_paid NUMERIC(12,2);
  v_due NUMERIC(12,2);
  v_schedule_id UUID;
BEGIN
  v_schedule_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.payment_schedule_id
    ELSE NEW.payment_schedule_id
  END;
  IF v_schedule_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  SELECT amount_due + late_fee_amount INTO v_due
  FROM public.payment_schedules WHERE id = v_schedule_id;

  SELECT COALESCE(SUM(allocated_amount), 0) INTO v_paid
  FROM public.payment_allocations WHERE payment_schedule_id = v_schedule_id;

  UPDATE public.payment_schedules
  SET amount_paid = v_paid,
      schedule_status = CASE
        WHEN v_paid <= 0 AND due_at < NOW() THEN 'overdue'
        WHEN v_paid <= 0 THEN 'pending'
        WHEN v_paid < v_due THEN 'partial'
        ELSE 'paid'
      END,
      updated_at = NOW()
  WHERE id = v_schedule_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_payment_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.payment_status = 'completed' AND (TG_OP = 'INSERT' OR OLD.payment_status IS DISTINCT FROM NEW.payment_status) THEN
    IF NEW.paid_at IS NULL THEN NEW.paid_at := NOW(); END IF;

    IF NEW.payment_schedule_id IS NOT NULL THEN
      INSERT INTO public.payment_allocations (payment_id, payment_schedule_id, invoice_id, allocated_amount)
      VALUES (NEW.id, NEW.payment_schedule_id, NEW.invoice_id, NEW.amount);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_after_payment_write()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_enrollment_id UUID;
BEGIN
  v_enrollment_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.enrollment_id
    ELSE NEW.enrollment_id
  END;
  PERFORM public.refresh_enrollment_state(v_enrollment_id);
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.can_access_course(p_course_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    public.is_admin(p_user_id)
    OR EXISTS (
      SELECT 1 FROM public.course_mentor_assignments cma
      WHERE cma.course_id = p_course_id AND cma.mentor_user_id = p_user_id AND cma.is_active = TRUE
    )
    OR EXISTS (
      SELECT 1 FROM public.enrollments e
      WHERE e.course_id = p_course_id
        AND e.student_user_id = p_user_id
        AND e.enrollment_status IN ('active', 'completed')
        AND e.access_status = 'active'
    );
$$;

CREATE OR REPLACE FUNCTION public.can_access_lesson(p_lesson_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.course_lessons l
      WHERE l.id = p_lesson_id AND l.access_tier = 'preview' AND l.is_published = TRUE
    ) THEN TRUE
    ELSE EXISTS (
      SELECT 1 FROM public.course_lessons l
      WHERE l.id = p_lesson_id
        AND l.is_published = TRUE
        AND (
          public.can_access_course(l.course_id, p_user_id)
          OR (
            l.access_tier = 'enrolled'
            AND EXISTS (
              SELECT 1 FROM public.enrollments e
              WHERE e.course_id = l.course_id
                AND e.student_user_id = p_user_id
                AND e.enrollment_status IN ('pending', 'active', 'completed')
            )
          )
        )
    )
  END;
$$;
CREATE OR REPLACE FUNCTION public.issue_video_access_session(
  p_lesson_id UUID,
  p_enrollment_id UUID,
  p_device_fingerprint TEXT,
  p_ip_address INET
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_course_id UUID;
  v_session_ttl INT;
  v_session_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  IF NOT public.can_access_lesson(p_lesson_id, v_user_id) THEN
    INSERT INTO public.course_access_logs (
      student_user_id, lesson_id, enrollment_id, action_name, action_result, ip_address, device_fingerprint
    ) VALUES (
      v_user_id, p_lesson_id, p_enrollment_id, 'video_session_denied', 'denied', p_ip_address, p_device_fingerprint
    );
    RAISE EXCEPTION 'Lesson access denied';
  END IF;

  SELECT l.course_id, ap.session_ttl_minutes
  INTO v_course_id, v_session_ttl
  FROM public.course_lessons l
  JOIN public.course_access_policies ap ON ap.course_id = l.course_id
  WHERE l.id = p_lesson_id;

  UPDATE public.video_access_sessions
  SET revoked_at = NOW(), revocation_reason = 'Superseded by a new playback session'
  WHERE student_user_id = v_user_id
    AND lesson_id = p_lesson_id
    AND revoked_at IS NULL
    AND expires_at > NOW();

  INSERT INTO public.video_access_sessions (
    student_user_id, course_id, lesson_id, enrollment_id, access_token_hash,
    device_fingerprint, ip_address, expires_at
  ) VALUES (
    v_user_id, v_course_id, p_lesson_id, p_enrollment_id,
    encode(digest(gen_random_uuid()::TEXT || clock_timestamp()::TEXT, 'sha256'), 'hex'),
    p_device_fingerprint, p_ip_address,
    NOW() + make_interval(mins => COALESCE(v_session_ttl, 120))
  ) RETURNING id INTO v_session_id;

  INSERT INTO public.course_access_logs (
    student_user_id, course_id, lesson_id, enrollment_id, action_name, action_result, ip_address, device_fingerprint
  ) VALUES (
    v_user_id, v_course_id, p_lesson_id, p_enrollment_id, 'video_session_issued', 'success', p_ip_address, p_device_fingerprint
  );

  RETURN v_session_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_form_submission_compat()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.submitted_by_user_id IS NULL AND NEW.user_id IS NOT NULL THEN
    NEW.submitted_by_user_id := NEW.user_id;
  END IF;

  IF NEW.user_id IS NULL AND NEW.submitted_by_user_id IS NOT NULL THEN
    NEW.user_id := NEW.submitted_by_user_id;
  END IF;

  IF (NEW.submission_data IS NULL OR NEW.submission_data = '{}'::jsonb) AND NEW.form_data IS NOT NULL THEN
    NEW.submission_data := NEW.form_data;
  END IF;

  IF (NEW.form_data IS NULL OR NEW.form_data = '{}'::jsonb) AND NEW.submission_data IS NOT NULL THEN
    NEW.form_data := NEW.submission_data;
  END IF;

  IF NEW.submitted_at IS NULL THEN
    NEW.submitted_at := COALESCE(NEW.created_at, NOW());
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_row_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.activity_logs (
    actor_user_id, actor_type, entity_type, entity_id, action_name, old_values, new_values
  ) VALUES (
    auth.uid(),
    COALESCE(public.current_actor_type(), 'system'),
    TG_TABLE_NAME,
    CASE
      WHEN TG_OP = 'DELETE' THEN COALESCE(OLD.id::TEXT, OLD.user_id::TEXT)
      ELSE COALESCE(NEW.id::TEXT, NEW.user_id::TEXT)
    END,
    LOWER(TG_OP),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================
-- TRIGGERS
-- ============================================================
DROP TRIGGER IF EXISTS trg_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER trg_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_student_profiles_updated_at ON public.student_profiles;
CREATE TRIGGER trg_student_profiles_updated_at BEFORE UPDATE ON public.student_profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_mentor_profiles_updated_at ON public.mentor_profiles;
CREATE TRIGGER trg_mentor_profiles_updated_at BEFORE UPDATE ON public.mentor_profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_admin_profiles_updated_at ON public.admin_profiles;
CREATE TRIGGER trg_admin_profiles_updated_at BEFORE UPDATE ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_categories_updated_at ON public.course_categories;
CREATE TRIGGER trg_course_categories_updated_at BEFORE UPDATE ON public.course_categories FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_courses_updated_at ON public.courses;
CREATE TRIGGER trg_courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_pricing_updated_at ON public.course_pricing;
CREATE TRIGGER trg_course_pricing_updated_at BEFORE UPDATE ON public.course_pricing FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_discounts_updated_at ON public.course_discounts;
CREATE TRIGGER trg_course_discounts_updated_at BEFORE UPDATE ON public.course_discounts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_access_policies_updated_at ON public.course_access_policies;
CREATE TRIGGER trg_course_access_policies_updated_at BEFORE UPDATE ON public.course_access_policies FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_mentor_assignments_updated_at ON public.course_mentor_assignments;
CREATE TRIGGER trg_course_mentor_assignments_updated_at BEFORE UPDATE ON public.course_mentor_assignments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_batches_updated_at ON public.course_batches;
CREATE TRIGGER trg_course_batches_updated_at BEFORE UPDATE ON public.course_batches FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_modules_updated_at ON public.course_modules;
CREATE TRIGGER trg_course_modules_updated_at BEFORE UPDATE ON public.course_modules FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_course_lessons_updated_at ON public.course_lessons;
CREATE TRIGGER trg_course_lessons_updated_at BEFORE UPDATE ON public.course_lessons FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_lesson_media_assets_updated_at ON public.lesson_media_assets;
CREATE TRIGGER trg_lesson_media_assets_updated_at BEFORE UPDATE ON public.lesson_media_assets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_enrollments_updated_at ON public.enrollments;
CREATE TRIGGER trg_enrollments_updated_at BEFORE UPDATE ON public.enrollments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_invoices_updated_at ON public.invoices;
CREATE TRIGGER trg_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_payment_schedules_updated_at ON public.payment_schedules;
CREATE TRIGGER trg_payment_schedules_updated_at BEFORE UPDATE ON public.payment_schedules FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_payments_updated_at ON public.payments;
CREATE TRIGGER trg_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_class_sessions_updated_at ON public.class_sessions;
CREATE TRIGGER trg_class_sessions_updated_at BEFORE UPDATE ON public.class_sessions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_class_attendance_updated_at ON public.class_attendance;
CREATE TRIGGER trg_class_attendance_updated_at BEFORE UPDATE ON public.class_attendance FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_admin_portal_access_updated_at ON public.admin_portal_access;
CREATE TRIGGER trg_admin_portal_access_updated_at BEFORE UPDATE ON public.admin_portal_access FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_mentor_documents_updated_at ON public.mentor_documents;
CREATE TRIGGER trg_mentor_documents_updated_at BEFORE UPDATE ON public.mentor_documents FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_form_submissions_updated_at ON public.form_submissions;
CREATE TRIGGER trg_form_submissions_updated_at BEFORE UPDATE ON public.form_submissions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_form_submissions_compat ON public.form_submissions;
CREATE TRIGGER trg_form_submissions_compat BEFORE INSERT OR UPDATE ON public.form_submissions FOR EACH ROW EXECUTE FUNCTION public.sync_form_submission_compat();
DROP TRIGGER IF EXISTS trg_feedback_updated_at ON public.feedback;
CREATE TRIGGER trg_feedback_updated_at BEFORE UPDATE ON public.feedback FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_reviews_updated_at ON public.reviews;
CREATE TRIGGER trg_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_inquiries_updated_at ON public.inquiries;
CREATE TRIGGER trg_inquiries_updated_at BEFORE UPDATE ON public.inquiries FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_complaints_updated_at ON public.complaints;
CREATE TRIGGER trg_complaints_updated_at BEFORE UPDATE ON public.complaints FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_live_recordings_updated_at ON public.live_recordings;
CREATE TRIGGER trg_live_recordings_updated_at BEFORE UPDATE ON public.live_recordings FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_meeting_requests_updated_at ON public.meeting_requests;
CREATE TRIGGER trg_meeting_requests_updated_at BEFORE UPDATE ON public.meeting_requests FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
DROP TRIGGER IF EXISTS trg_mentor_salary_payments_updated_at ON public.mentor_salary_payments;
CREATE TRIGGER trg_mentor_salary_payments_updated_at BEFORE UPDATE ON public.mentor_salary_payments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_payments_handle_status_change ON public.payments;
CREATE TRIGGER trg_payments_handle_status_change
BEFORE INSERT OR UPDATE OF payment_status ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.handle_payment_status_change();

DROP TRIGGER IF EXISTS trg_payment_allocations_sync_schedule ON public.payment_allocations;
CREATE TRIGGER trg_payment_allocations_sync_schedule
AFTER INSERT OR UPDATE OR DELETE ON public.payment_allocations
FOR EACH ROW EXECUTE FUNCTION public.sync_payment_schedule_state();

DROP TRIGGER IF EXISTS trg_payments_refresh_enrollment ON public.payments;
CREATE TRIGGER trg_payments_refresh_enrollment
AFTER INSERT OR UPDATE OR DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.refresh_after_payment_write();

CREATE OR REPLACE FUNCTION public.handle_batch_enrollment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.refresh_batch_student_count(
    CASE
      WHEN TG_OP = 'DELETE' THEN OLD.batch_id
      ELSE NEW.batch_id
    END
  );
  IF TG_OP = 'UPDATE' AND OLD.batch_id IS DISTINCT FROM NEW.batch_id THEN
    PERFORM public.refresh_batch_student_count(OLD.batch_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_enrollments_batch_counts ON public.enrollments;
CREATE TRIGGER trg_enrollments_batch_counts
AFTER INSERT OR UPDATE OR DELETE ON public.enrollments
FOR EACH ROW EXECUTE FUNCTION public.handle_batch_enrollment_change();

CREATE OR REPLACE FUNCTION public.handle_mentor_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.refresh_mentor_counters(
    CASE
      WHEN TG_OP = 'DELETE' THEN OLD.primary_mentor_user_id
      ELSE NEW.primary_mentor_user_id
    END
  );
  IF TG_OP = 'UPDATE' AND OLD.primary_mentor_user_id IS DISTINCT FROM NEW.primary_mentor_user_id THEN
    PERFORM public.refresh_mentor_counters(OLD.primary_mentor_user_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_batches_refresh_mentor ON public.course_batches;
CREATE TRIGGER trg_batches_refresh_mentor
AFTER INSERT OR UPDATE OR DELETE ON public.course_batches
FOR EACH ROW EXECUTE FUNCTION public.handle_mentor_refresh();

CREATE OR REPLACE FUNCTION public.handle_class_session_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.refresh_mentor_counters(
    CASE
      WHEN TG_OP = 'DELETE' THEN OLD.mentor_user_id
      ELSE NEW.mentor_user_id
    END
  );
  IF TG_OP = 'UPDATE' AND OLD.mentor_user_id IS DISTINCT FROM NEW.mentor_user_id THEN
    PERFORM public.refresh_mentor_counters(OLD.mentor_user_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_class_sessions_refresh_mentor ON public.class_sessions;
CREATE TRIGGER trg_class_sessions_refresh_mentor
AFTER INSERT OR UPDATE OR DELETE ON public.class_sessions
FOR EACH ROW EXECUTE FUNCTION public.handle_class_session_refresh();

DROP TRIGGER IF EXISTS trg_courses_activity ON public.courses;
CREATE TRIGGER trg_courses_activity AFTER INSERT OR UPDATE OR DELETE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_row_activity();
DROP TRIGGER IF EXISTS trg_enrollments_activity ON public.enrollments;
CREATE TRIGGER trg_enrollments_activity AFTER INSERT OR UPDATE OR DELETE ON public.enrollments FOR EACH ROW EXECUTE FUNCTION public.log_row_activity();
DROP TRIGGER IF EXISTS trg_payments_activity ON public.payments;
CREATE TRIGGER trg_payments_activity AFTER INSERT OR UPDATE OR DELETE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.log_row_activity();
DROP TRIGGER IF EXISTS trg_user_profiles_activity ON public.user_profiles;
CREATE TRIGGER trg_user_profiles_activity AFTER INSERT OR UPDATE OR DELETE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.log_row_activity();
-- ============================================================
-- REPORTING VIEWS
-- ============================================================
CREATE OR REPLACE VIEW public.v_course_revenue_summary AS
SELECT
  c.id AS course_id,
  c.title AS course_title,
  c.course_status,
  COUNT(DISTINCT e.id) FILTER (WHERE e.enrollment_status IN ('pending', 'active', 'completed')) AS enrolled_students,
  COALESCE(SUM(e.net_amount), 0) AS contracted_revenue,
  COALESCE(SUM(e.paid_amount), 0) AS collected_revenue,
  COALESCE(SUM(e.due_amount), 0) AS outstanding_revenue
FROM public.courses c
LEFT JOIN public.enrollments e ON e.course_id = c.id
GROUP BY c.id, c.title, c.course_status;

CREATE OR REPLACE VIEW public.v_student_financial_summary AS
SELECT
  up.user_id AS student_user_id,
  up.full_name,
  up.email,
  COUNT(e.id) AS total_enrollments,
  COALESCE(SUM(e.net_amount), 0) AS total_fees,
  COALESCE(SUM(e.paid_amount), 0) AS total_paid,
  COALESCE(SUM(e.due_amount), 0) AS total_due
FROM public.user_profiles up
JOIN public.student_profiles sp ON sp.user_id = up.user_id
LEFT JOIN public.enrollments e ON e.student_user_id = sp.user_id
GROUP BY up.user_id, up.full_name, up.email;

CREATE OR REPLACE VIEW public.v_mentor_workload AS
SELECT
  mp.user_id AS mentor_user_id,
  up.full_name AS mentor_name,
  mp.status,
  mp.total_students_managed,
  mp.total_classes_assigned,
  COUNT(DISTINCT cma.course_id) FILTER (WHERE cma.is_active = TRUE) AS active_course_assignments,
  COUNT(DISTINCT cb.id) FILTER (WHERE cb.is_active = TRUE) AS active_batches
FROM public.mentor_profiles mp
JOIN public.user_profiles up ON up.user_id = mp.user_id
LEFT JOIN public.course_mentor_assignments cma ON cma.mentor_user_id = mp.user_id
LEFT JOIN public.course_batches cb ON cb.primary_mentor_user_id = mp.user_id
GROUP BY mp.user_id, up.full_name, mp.status, mp.total_students_managed, mp.total_classes_assigned;

CREATE OR REPLACE VIEW public.v_admin_fee_report AS
SELECT
  e.id AS enrollment_id,
  e.student_user_id,
  up.full_name AS student_name,
  c.id AS course_id,
  c.title AS course_title,
  e.net_amount,
  e.paid_amount,
  e.due_amount,
  e.enrollment_status,
  e.access_status,
  e.first_payment_due_at,
  e.final_payment_due_at
FROM public.enrollments e
JOIN public.user_profiles up ON up.user_id = e.student_user_id
JOIN public.courses c ON c.id = e.course_id;

CREATE OR REPLACE VIEW public.v_admin_student_progress_report AS
SELECT
  e.student_user_id,
  up.full_name AS student_name,
  c.id AS course_id,
  c.title AS course_title,
  e.progress_percentage,
  e.enrollment_status,
  e.access_status,
  e.last_accessed_at,
  e.completed_at
FROM public.enrollments e
JOIN public.user_profiles up ON up.user_id = e.student_user_id
JOIN public.courses c ON c.id = e.course_id;

CREATE OR REPLACE VIEW public.v_admin_feedback_summary AS
SELECT
  f.feedback_type,
  COUNT(*) AS total_feedback,
  COUNT(*) FILTER (WHERE f.status = 'open') AS open_feedback,
  ROUND(AVG(f.rating)::NUMERIC, 2) AS avg_rating
FROM public.feedback f
GROUP BY f.feedback_type;

CREATE OR REPLACE VIEW public.v_admin_complaint_summary AS
SELECT
  c.category,
  c.priority,
  c.status,
  COUNT(*) AS total_items
FROM public.complaints c
GROUP BY c.category, c.priority, c.status;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_access_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_mentor_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_publications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_media_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollment_discount_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_access_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_access_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_performance_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_portal_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_login_otp_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signup_email_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_recordings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_salary_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_profiles_self_or_admin_select ON public.user_profiles;
CREATE POLICY user_profiles_self_or_admin_select ON public.user_profiles FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS user_profiles_self_insert ON public.user_profiles;
CREATE POLICY user_profiles_self_insert ON public.user_profiles FOR INSERT WITH CHECK (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS user_profiles_self_update ON public.user_profiles;
CREATE POLICY user_profiles_self_update ON public.user_profiles FOR UPDATE USING (user_id = auth.uid() OR public.is_admin()) WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS role_assignments_admin_read ON public.user_role_assignments;
CREATE POLICY role_assignments_admin_read ON public.user_role_assignments FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS role_assignments_super_admin_manage ON public.user_role_assignments;
CREATE POLICY role_assignments_super_admin_manage ON public.user_role_assignments FOR ALL USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS student_profiles_self_or_admin ON public.student_profiles;
CREATE POLICY student_profiles_self_or_admin ON public.student_profiles FOR ALL USING (user_id = auth.uid() OR public.is_admin()) WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS mentor_profiles_read ON public.mentor_profiles;
CREATE POLICY mentor_profiles_read ON public.mentor_profiles FOR SELECT USING (status = 'approved' OR user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS mentor_profiles_self_update ON public.mentor_profiles;
CREATE POLICY mentor_profiles_self_update ON public.mentor_profiles FOR UPDATE USING (user_id = auth.uid() OR public.is_admin()) WITH CHECK (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS mentor_profiles_self_insert ON public.mentor_profiles;
CREATE POLICY mentor_profiles_self_insert ON public.mentor_profiles FOR INSERT WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS admin_profiles_admin_only ON public.admin_profiles;
CREATE POLICY admin_profiles_admin_only ON public.admin_profiles FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS categories_public_read ON public.course_categories;
CREATE POLICY categories_public_read ON public.course_categories FOR SELECT USING (is_active = TRUE OR public.is_admin());
DROP POLICY IF EXISTS categories_admin_manage ON public.course_categories;
CREATE POLICY categories_admin_manage ON public.course_categories FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS courses_read_policy ON public.courses;
CREATE POLICY courses_read_policy ON public.courses FOR SELECT USING (
  public.is_admin()
  OR EXISTS (SELECT 1 FROM public.course_mentor_assignments cma WHERE cma.course_id = courses.id AND cma.mentor_user_id = auth.uid() AND cma.is_active = TRUE)
  OR (courses.course_status = 'published' AND courses.visibility IN ('public', 'unlisted'))
  OR EXISTS (SELECT 1 FROM public.enrollments e WHERE e.course_id = courses.id AND e.student_user_id = auth.uid())
);
DROP POLICY IF EXISTS courses_admin_manage ON public.courses;
CREATE POLICY courses_admin_manage ON public.courses FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS course_pricing_read_policy ON public.course_pricing;
CREATE POLICY course_pricing_read_policy ON public.course_pricing FOR SELECT USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.courses c WHERE c.id = course_pricing.course_id AND c.course_status = 'published' AND c.visibility IN ('public', 'unlisted')
  )
);
DROP POLICY IF EXISTS course_pricing_admin_manage ON public.course_pricing;
CREATE POLICY course_pricing_admin_manage ON public.course_pricing FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS course_discounts_admin_only ON public.course_discounts;
CREATE POLICY course_discounts_admin_only ON public.course_discounts FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS access_policies_admin_only ON public.course_access_policies;
CREATE POLICY access_policies_admin_only ON public.course_access_policies FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS mentor_assignments_read_policy ON public.course_mentor_assignments;
CREATE POLICY mentor_assignments_read_policy ON public.course_mentor_assignments FOR SELECT USING (public.is_admin() OR mentor_user_id = auth.uid());
DROP POLICY IF EXISTS mentor_assignments_admin_manage ON public.course_mentor_assignments;
CREATE POLICY mentor_assignments_admin_manage ON public.course_mentor_assignments FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS batches_read_policy ON public.course_batches;
CREATE POLICY batches_read_policy ON public.course_batches FOR SELECT USING (
  public.is_admin() OR primary_mentor_user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.enrollments e WHERE e.batch_id = course_batches.id AND e.student_user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS batches_manage_policy ON public.course_batches;
CREATE POLICY batches_manage_policy ON public.course_batches FOR ALL USING (public.is_admin() OR primary_mentor_user_id = auth.uid()) WITH CHECK (public.is_admin() OR primary_mentor_user_id = auth.uid());

DROP POLICY IF EXISTS publications_read_policy ON public.course_publications;
CREATE POLICY publications_read_policy ON public.course_publications FOR SELECT USING (public.is_admin() OR EXISTS (SELECT 1 FROM public.courses c WHERE c.id = course_publications.course_id AND c.course_status = 'published'));
DROP POLICY IF EXISTS publications_admin_manage ON public.course_publications;
CREATE POLICY publications_admin_manage ON public.course_publications FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS modules_read_policy ON public.course_modules;
CREATE POLICY modules_read_policy ON public.course_modules FOR SELECT USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.courses c
    WHERE c.id = course_modules.course_id
      AND c.course_status = 'published'
      AND (c.visibility IN ('public', 'unlisted') OR public.can_access_course(c.id))
  )
);
DROP POLICY IF EXISTS modules_admin_manage ON public.course_modules;
CREATE POLICY modules_admin_manage ON public.course_modules FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS lessons_read_policy ON public.course_lessons;
CREATE POLICY lessons_read_policy ON public.course_lessons FOR SELECT USING (public.can_access_lesson(id) OR public.is_admin());
DROP POLICY IF EXISTS lessons_admin_manage ON public.course_lessons;
CREATE POLICY lessons_admin_manage ON public.course_lessons FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS assets_read_policy ON public.lesson_media_assets;
CREATE POLICY assets_read_policy ON public.lesson_media_assets FOR SELECT USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.course_lessons l WHERE l.id = lesson_media_assets.lesson_id AND public.can_access_lesson(l.id)
  )
);
DROP POLICY IF EXISTS assets_admin_manage ON public.lesson_media_assets;
CREATE POLICY assets_admin_manage ON public.lesson_media_assets FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS enrollments_own_or_admin_or_mentor ON public.enrollments;
CREATE POLICY enrollments_own_or_admin_or_mentor ON public.enrollments FOR SELECT USING (
  student_user_id = auth.uid() OR public.is_admin() OR EXISTS (
    SELECT 1 FROM public.course_mentor_assignments cma
    WHERE cma.course_id = enrollments.course_id AND cma.mentor_user_id = auth.uid() AND cma.is_active = TRUE
  )
);
DROP POLICY IF EXISTS enrollments_insert_own_or_admin ON public.enrollments;
CREATE POLICY enrollments_insert_own_or_admin ON public.enrollments FOR INSERT WITH CHECK (student_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS enrollments_update_admin_only ON public.enrollments;
CREATE POLICY enrollments_update_admin_only ON public.enrollments FOR UPDATE USING (student_user_id = auth.uid() OR public.is_admin()) WITH CHECK (student_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS enrollment_discounts_admin_only ON public.enrollment_discount_applications;
CREATE POLICY enrollment_discounts_admin_only ON public.enrollment_discount_applications FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS invoices_own_or_admin ON public.invoices;
CREATE POLICY invoices_own_or_admin ON public.invoices FOR SELECT USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.enrollments e WHERE e.id = invoices.enrollment_id AND e.student_user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS invoices_admin_manage ON public.invoices;
CREATE POLICY invoices_admin_manage ON public.invoices FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS schedules_own_or_admin ON public.payment_schedules;
CREATE POLICY schedules_own_or_admin ON public.payment_schedules FOR SELECT USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.enrollments e WHERE e.id = payment_schedules.enrollment_id AND e.student_user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS schedules_admin_manage ON public.payment_schedules;
CREATE POLICY schedules_admin_manage ON public.payment_schedules FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS payments_own_or_admin ON public.payments;
CREATE POLICY payments_own_or_admin ON public.payments FOR SELECT USING (student_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS payments_insert_own_or_admin ON public.payments;
CREATE POLICY payments_insert_own_or_admin ON public.payments FOR INSERT WITH CHECK (student_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS payments_update_admin_only ON public.payments;
CREATE POLICY payments_update_admin_only ON public.payments FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS payment_allocations_admin_only ON public.payment_allocations;
CREATE POLICY payment_allocations_admin_only ON public.payment_allocations FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS refunds_own_or_admin_select ON public.refunds;
CREATE POLICY refunds_own_or_admin_select ON public.refunds FOR SELECT USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.payments p WHERE p.id = refunds.payment_id AND p.student_user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS refunds_admin_manage ON public.refunds;
CREATE POLICY refunds_admin_manage ON public.refunds FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS class_sessions_visibility ON public.class_sessions;
CREATE POLICY class_sessions_visibility ON public.class_sessions FOR SELECT USING (
  public.is_admin() OR mentor_user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.enrollments e
    WHERE e.batch_id = class_sessions.batch_id AND e.student_user_id = auth.uid() AND e.access_status IN ('active', 'restricted')
  )
);
DROP POLICY IF EXISTS class_sessions_manage_policy ON public.class_sessions;
CREATE POLICY class_sessions_manage_policy ON public.class_sessions FOR ALL USING (public.is_admin() OR mentor_user_id = auth.uid()) WITH CHECK (public.is_admin() OR mentor_user_id = auth.uid());

DROP POLICY IF EXISTS attendance_visibility ON public.class_attendance;
CREATE POLICY attendance_visibility ON public.class_attendance FOR SELECT USING (
  public.is_admin() OR student_user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.class_sessions cs WHERE cs.id = class_attendance.class_session_id AND cs.mentor_user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS attendance_manage_policy ON public.class_attendance;
CREATE POLICY attendance_manage_policy ON public.class_attendance FOR ALL USING (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.class_sessions cs WHERE cs.id = class_attendance.class_session_id AND cs.mentor_user_id = auth.uid()
  )
) WITH CHECK (
  public.is_admin() OR EXISTS (
    SELECT 1 FROM public.class_sessions cs WHERE cs.id = class_attendance.class_session_id AND cs.mentor_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS access_logs_own_or_admin ON public.course_access_logs;
CREATE POLICY access_logs_own_or_admin ON public.course_access_logs FOR SELECT USING (student_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS access_logs_insert_own_or_system ON public.course_access_logs;
CREATE POLICY access_logs_insert_own_or_system ON public.course_access_logs FOR INSERT WITH CHECK (student_user_id = auth.uid() OR public.is_admin() OR auth.uid() IS NULL);

DROP POLICY IF EXISTS video_sessions_own_or_admin ON public.video_access_sessions;
CREATE POLICY video_sessions_own_or_admin ON public.video_access_sessions FOR SELECT USING (student_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS video_sessions_insert_own_or_admin ON public.video_access_sessions;
CREATE POLICY video_sessions_insert_own_or_admin ON public.video_access_sessions FOR INSERT WITH CHECK (student_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS mentor_reports_visibility ON public.mentor_performance_reports;
CREATE POLICY mentor_reports_visibility ON public.mentor_performance_reports FOR SELECT USING (mentor_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS mentor_reports_admin_manage ON public.mentor_performance_reports;
CREATE POLICY mentor_reports_admin_manage ON public.mentor_performance_reports FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS activity_logs_admin_read ON public.activity_logs;
CREATE POLICY activity_logs_admin_read ON public.activity_logs FOR SELECT USING (public.is_admin());
DROP POLICY IF EXISTS activity_logs_insert_any ON public.activity_logs;
CREATE POLICY activity_logs_insert_any ON public.activity_logs FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS auth_activity_logs_self_or_admin ON public.auth_activity_logs;
CREATE POLICY auth_activity_logs_self_or_admin ON public.auth_activity_logs FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS auth_activity_logs_insert_any ON public.auth_activity_logs;
CREATE POLICY auth_activity_logs_insert_any ON public.auth_activity_logs FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS admin_portal_access_self_or_admin ON public.admin_portal_access;
CREATE POLICY admin_portal_access_self_or_admin ON public.admin_portal_access FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS admin_portal_access_admin_manage ON public.admin_portal_access;
CREATE POLICY admin_portal_access_admin_manage ON public.admin_portal_access FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS admin_login_otp_self_or_admin ON public.admin_login_otp_challenges;
CREATE POLICY admin_login_otp_self_or_admin ON public.admin_login_otp_challenges FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS admin_login_otp_insert_system ON public.admin_login_otp_challenges;
CREATE POLICY admin_login_otp_insert_system ON public.admin_login_otp_challenges FOR INSERT WITH CHECK (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS admin_login_otp_update_self_or_admin ON public.admin_login_otp_challenges;
CREATE POLICY admin_login_otp_update_self_or_admin ON public.admin_login_otp_challenges FOR UPDATE USING (user_id = auth.uid() OR public.is_admin()) WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS signup_otps_access ON public.signup_email_otps;
CREATE POLICY signup_otps_access ON public.signup_email_otps FOR ALL USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS sms_verification_self_or_admin ON public.sms_verification_requests;
CREATE POLICY sms_verification_self_or_admin ON public.sms_verification_requests FOR ALL USING (user_id = auth.uid() OR public.is_admin() OR user_id IS NULL) WITH CHECK (user_id = auth.uid() OR public.is_admin() OR user_id IS NULL);

DROP POLICY IF EXISTS mentor_documents_read_policy ON public.mentor_documents;
CREATE POLICY mentor_documents_read_policy ON public.mentor_documents FOR SELECT USING (mentor_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS mentor_documents_write_policy ON public.mentor_documents;
CREATE POLICY mentor_documents_write_policy ON public.mentor_documents FOR ALL USING (mentor_user_id = auth.uid() OR public.is_admin()) WITH CHECK (mentor_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS form_submissions_read_policy ON public.form_submissions;
CREATE POLICY form_submissions_read_policy ON public.form_submissions FOR SELECT USING (submitted_by_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS form_submissions_insert_policy ON public.form_submissions;
CREATE POLICY form_submissions_insert_policy ON public.form_submissions FOR INSERT WITH CHECK (submitted_by_user_id = auth.uid() OR submitted_by_user_id IS NULL OR public.is_admin());
DROP POLICY IF EXISTS form_submissions_update_policy ON public.form_submissions;
CREATE POLICY form_submissions_update_policy ON public.form_submissions FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS feedback_read_policy ON public.feedback;
CREATE POLICY feedback_read_policy ON public.feedback FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS feedback_insert_policy ON public.feedback;
CREATE POLICY feedback_insert_policy ON public.feedback FOR INSERT WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());
DROP POLICY IF EXISTS feedback_update_policy ON public.feedback;
CREATE POLICY feedback_update_policy ON public.feedback FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS reviews_read_policy ON public.reviews;
CREATE POLICY reviews_read_policy ON public.reviews FOR SELECT USING (is_approved = TRUE OR user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS reviews_insert_policy ON public.reviews;
CREATE POLICY reviews_insert_policy ON public.reviews FOR INSERT WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());
DROP POLICY IF EXISTS reviews_update_policy ON public.reviews;
CREATE POLICY reviews_update_policy ON public.reviews FOR UPDATE USING (user_id = auth.uid() OR public.is_admin()) WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS inquiries_read_policy ON public.inquiries;
CREATE POLICY inquiries_read_policy ON public.inquiries FOR SELECT USING (user_id = auth.uid() OR assigned_admin_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS inquiries_insert_policy ON public.inquiries;
CREATE POLICY inquiries_insert_policy ON public.inquiries FOR INSERT WITH CHECK (user_id = auth.uid() OR user_id IS NULL OR public.is_admin());
DROP POLICY IF EXISTS inquiries_update_policy ON public.inquiries;
CREATE POLICY inquiries_update_policy ON public.inquiries FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS complaints_read_policy ON public.complaints;
CREATE POLICY complaints_read_policy ON public.complaints FOR SELECT USING (submitted_by_user_id = auth.uid() OR assigned_admin_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS complaints_insert_policy ON public.complaints;
CREATE POLICY complaints_insert_policy ON public.complaints FOR INSERT WITH CHECK (submitted_by_user_id = auth.uid() OR submitted_by_user_id IS NULL OR public.is_admin());
DROP POLICY IF EXISTS complaints_update_policy ON public.complaints;
CREATE POLICY complaints_update_policy ON public.complaints FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS live_recordings_read_policy ON public.live_recordings;
CREATE POLICY live_recordings_read_policy ON public.live_recordings FOR SELECT USING (
  public.is_admin()
  OR (access_level = 'public' AND is_published = TRUE)
  OR (
    access_level = 'enrolled'
    AND EXISTS (
      SELECT 1 FROM public.enrollments e
      WHERE e.course_id = live_recordings.course_id
        AND e.student_user_id = auth.uid()
        AND e.enrollment_status IN ('pending', 'active', 'completed')
    )
  )
  OR (
    access_level = 'paid'
    AND public.can_access_course(live_recordings.course_id)
  )
);
DROP POLICY IF EXISTS live_recordings_admin_manage ON public.live_recordings;
CREATE POLICY live_recordings_admin_manage ON public.live_recordings FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS meeting_requests_read_policy ON public.meeting_requests;
CREATE POLICY meeting_requests_read_policy ON public.meeting_requests FOR SELECT USING (requester_user_id = auth.uid() OR mentor_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS meeting_requests_insert_policy ON public.meeting_requests;
CREATE POLICY meeting_requests_insert_policy ON public.meeting_requests FOR INSERT WITH CHECK (requester_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS meeting_requests_update_policy ON public.meeting_requests;
CREATE POLICY meeting_requests_update_policy ON public.meeting_requests FOR UPDATE USING (mentor_user_id = auth.uid() OR public.is_admin()) WITH CHECK (mentor_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS mentor_salary_read_policy ON public.mentor_salary_payments;
CREATE POLICY mentor_salary_read_policy ON public.mentor_salary_payments FOR SELECT USING (mentor_user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS mentor_salary_admin_manage ON public.mentor_salary_payments;
CREATE POLICY mentor_salary_admin_manage ON public.mentor_salary_payments FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles (email);
CREATE INDEX IF NOT EXISTS idx_role_assignments_user_active ON public.user_role_assignments (user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_status ON public.mentor_profiles (status);
CREATE INDEX IF NOT EXISTS idx_courses_category_status ON public.courses (category_id, course_status, visibility);
CREATE INDEX IF NOT EXISTS idx_course_pricing_course_active ON public.course_pricing (course_id, is_active, is_default);
CREATE INDEX IF NOT EXISTS idx_course_discounts_code ON public.course_discounts (discount_code) WHERE discount_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_course_assignments_course ON public.course_mentor_assignments (course_id, mentor_user_id);
CREATE INDEX IF NOT EXISTS idx_course_batches_course ON public.course_batches (course_id, is_active);
CREATE INDEX IF NOT EXISTS idx_course_lessons_course_module ON public.course_lessons (course_id, module_id, lesson_order);
CREATE INDEX IF NOT EXISTS idx_lesson_assets_lesson ON public.lesson_media_assets (lesson_id, is_active);
CREATE INDEX IF NOT EXISTS idx_enrollments_student_course ON public.enrollments (student_user_id, course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status_access ON public.enrollments (enrollment_status, access_status);
CREATE INDEX IF NOT EXISTS idx_invoices_enrollment_status ON public.invoices (enrollment_id, invoice_status);
CREATE INDEX IF NOT EXISTS idx_payment_schedules_due_status ON public.payment_schedules (due_at, schedule_status);
CREATE INDEX IF NOT EXISTS idx_payments_enrollment_status ON public.payments (enrollment_id, payment_status, paid_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_schedule ON public.payment_allocations (payment_schedule_id);
CREATE INDEX IF NOT EXISTS idx_class_sessions_batch_time ON public.class_sessions (batch_id, scheduled_start_at);
CREATE INDEX IF NOT EXISTS idx_attendance_session_student ON public.class_attendance (class_session_id, student_user_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_student_course_time ON public.course_access_logs (student_user_id, course_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_sessions_lookup ON public.video_access_sessions (student_user_id, lesson_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_time ON public.activity_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_portal_access_email ON public.admin_portal_access (authorized_email, portal_status);
CREATE INDEX IF NOT EXISTS idx_admin_login_otp_user_created ON public.admin_login_otp_challenges (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_signup_email_otps_email_created ON public.signup_email_otps (email, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_verification_phone_created ON public.sms_verification_requests (phone, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mentor_documents_mentor_type ON public.mentor_documents (mentor_user_id, document_type, verification_status);
CREATE INDEX IF NOT EXISTS idx_form_submissions_type_status ON public.form_submissions (form_type, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_type_status ON public.feedback (feedback_type, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_course_approved ON public.reviews (course_id, is_approved, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inquiries_status_priority ON public.inquiries (status, priority, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_status_priority ON public.complaints (status, priority, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_recordings_course_published ON public.live_recordings (course_id, is_published, access_level);
CREATE INDEX IF NOT EXISTS idx_meeting_requests_requester_time ON public.meeting_requests (requester_user_id, requested_start_at DESC);
CREATE INDEX IF NOT EXISTS idx_mentor_salary_mentor_period ON public.mentor_salary_payments (mentor_user_id, period_start DESC);

-- ============================================================
-- END
-- Clean install schema for a new database.
-- Add signed URLs / DRM / token validation in the app layer for
-- full media hardening beyond DB policy/session enforcement.
-- ============================================================
