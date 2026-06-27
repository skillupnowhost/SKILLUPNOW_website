-- ============================================================
-- v46 — Accurate Working Hours: Gap Tracking
-- Adds: gap_mins column to intern_work_sessions
-- Tracks idle/away time between end→resume cycles
-- Formula: net_work_mins = total_work_mins - total_break_mins - gap_mins
-- Run AFTER v45-network-tracking-and-bulk-delete.sql
-- ============================================================

ALTER TABLE public.intern_work_sessions
  ADD COLUMN IF NOT EXISTS gap_mins int DEFAULT 0;

COMMENT ON COLUMN public.intern_work_sessions.gap_mins IS
  'Accumulated idle/gap minutes from session end→resume cycles. Subtracted from total to get accurate net work time.';

-- Backfill: for completed sessions where net_work_mins was calculated without gaps,
-- set gap_mins = 0 (they had no resume cycles)
UPDATE public.intern_work_sessions
  SET gap_mins = 0
  WHERE gap_mins IS NULL;
