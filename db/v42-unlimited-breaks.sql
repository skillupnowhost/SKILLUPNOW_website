-- ============================================================
-- v42 — Allow unlimited breaks per session
-- Removes: break_number CHECK(1,2) constraint, UNIQUE(session_id, break_number)
-- Keeps: break_number column (auto-incremented in JS), duration_mins GENERATED
-- Total break time still capped at 2 hours in frontend logic
-- Run AFTER v41-fix-intern-assignment-rls.sql
-- ============================================================

-- Drop the CHECK constraint on break_number (allows any positive integer)
ALTER TABLE public.intern_breaks DROP CONSTRAINT IF EXISTS intern_breaks_break_number_check;

-- Add a new permissive CHECK (just must be >= 1)
ALTER TABLE public.intern_breaks ADD CONSTRAINT intern_breaks_break_number_check CHECK (break_number >= 1);

-- Drop the UNIQUE constraint that limits to 2 breaks per session
ALTER TABLE public.intern_breaks DROP CONSTRAINT IF EXISTS intern_breaks_session_id_break_number_key;
