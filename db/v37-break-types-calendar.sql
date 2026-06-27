-- v37: Break types dropdown, calendar day statuses, 8-hour workday tracking
-- Run this in Supabase SQL editor

-- Add break_type column to intern_breaks
ALTER TABLE intern_breaks ADD COLUMN IF NOT EXISTS break_type text DEFAULT 'general';

-- Add calendar_status to internship_attendance for storing day-specific display statuses
ALTER TABLE internship_attendance ADD COLUMN IF NOT EXISTS calendar_status text DEFAULT 'present';
-- Valid values: 'present', 'absent', 'holiday', 'leave', 'half_day'

-- Add total_break_mins to intern_work_sessions for quick reference
ALTER TABLE intern_work_sessions ADD COLUMN IF NOT EXISTS total_break_mins integer DEFAULT 0;

-- Add net_work_mins (total_work_mins minus total_break_mins) for 8-hour tracking
ALTER TABLE intern_work_sessions ADD COLUMN IF NOT EXISTS net_work_mins integer DEFAULT 0;

-- Update RLS policies to allow students to read/write their own break types
-- (existing policies should already cover this since break_type is just a column on intern_breaks)

-- Create index for faster attendance queries
CREATE INDEX IF NOT EXISTS idx_internship_attendance_date ON internship_attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_intern_work_sessions_date ON intern_work_sessions(session_date);
