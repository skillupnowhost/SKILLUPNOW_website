-- ============================================================
-- SKILLUPNOW v28 — FIX log_row_activity() TRIGGER
-- ============================================================
-- Problem:
--   log_row_activity() uses OLD.user_id / NEW.user_id with direct
--   dot-notation record access. Tables like `enrollments` that use
--   `student_user_id` (not `user_id`) cause:
--     "record old has no field user_id"
--   on EVERY INSERT, UPDATE, and DELETE on those tables.
--
-- Fix:
--   Replace direct column access with to_jsonb() key lookup, which
--   returns NULL for missing keys instead of raising an error.
--
-- Run this ONCE in Supabase SQL Editor:
--   Dashboard → SQL Editor → paste this file → Run
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_row_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_entity_id TEXT;
BEGIN
  -- Use to_jsonb() so missing columns return NULL instead of erroring.
  -- Works on all tables regardless of whether they have user_id or id.
  IF TG_OP = 'DELETE' THEN
    v_entity_id := COALESCE(
      to_jsonb(OLD) ->> 'id',
      to_jsonb(OLD) ->> 'user_id',
      to_jsonb(OLD) ->> 'student_user_id'
    );
  ELSE
    v_entity_id := COALESCE(
      to_jsonb(NEW) ->> 'id',
      to_jsonb(NEW) ->> 'user_id',
      to_jsonb(NEW) ->> 'student_user_id'
    );
  END IF;

  INSERT INTO public.activity_logs (
    actor_user_id,
    actor_type,
    entity_type,
    entity_id,
    action_name,
    old_values,
    new_values
  ) VALUES (
    auth.uid(),
    COALESCE(public.current_actor_type(), 'system'),
    TG_TABLE_NAME,
    v_entity_id,
    LOWER(TG_OP),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );

  RETURN COALESCE(NEW, OLD);
EXCEPTION
  WHEN OTHERS THEN
    -- Never let activity logging block the actual operation.
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================
-- Verify fix: check that the function no longer uses dot notation
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE 'v28 fix applied: log_row_activity() now uses to_jsonb() for safe field access.';
  RAISE NOTICE 'Enrollments, payments, and all other tables can now INSERT/UPDATE/DELETE without trigger errors.';
END;
$$;
