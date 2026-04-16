-- v24: Assign student to batch through a SECURITY DEFINER RPC
-- Fixes silent no-op updates under RLS when a dashboard tries to move an
-- existing course enrollment into a batch it should manage.

CREATE OR REPLACE FUNCTION public.assign_student_to_batch(
  p_student_user_id UUID,
  p_batch_id UUID
)
RETURNS public.enrollments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch        public.course_batches%ROWTYPE;
  v_enrollment   public.enrollments%ROWTYPE;
  v_pricing      public.course_pricing%ROWTYPE;
  v_is_allowed   BOOLEAN := FALSE;
  v_net_amount   NUMERIC(12,2);
BEGIN
  SELECT *
  INTO v_batch
  FROM public.course_batches
  WHERE id = p_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Batch not found';
  END IF;

  SELECT
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.admin_profiles ap
      WHERE ap.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.course_batches cb
      JOIN public.mentor_profiles mp ON mp.user_id = auth.uid()
      WHERE cb.id = p_batch_id
        AND cb.primary_mentor_user_id = auth.uid()
        AND mp.status = 'approved'
    )
  INTO v_is_allowed;

  IF COALESCE(v_is_allowed, FALSE) = FALSE THEN
    RAISE EXCEPTION 'You do not have permission to assign students to this batch';
  END IF;

  SELECT *
  INTO v_enrollment
  FROM public.enrollments
  WHERE student_user_id = p_student_user_id
    AND course_id = v_batch.course_id;

  IF FOUND THEN
    UPDATE public.enrollments
    SET
      batch_id = p_batch_id,
      enrollment_status = CASE
        WHEN enrollment_status IN ('completed') THEN enrollment_status
        ELSE 'active'::public.enrollment_status
      END,
      access_status = 'active'::public.access_status,
      updated_at = NOW()
    WHERE id = v_enrollment.id
    RETURNING *
    INTO v_enrollment;

    RETURN v_enrollment;
  END IF;

  SELECT *
  INTO v_pricing
  FROM public.course_pricing
  WHERE course_id = v_batch.course_id
    AND is_active = TRUE
  ORDER BY updated_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active pricing found for this course. Set pricing first.';
  END IF;

  v_net_amount := COALESCE(v_pricing.sale_price, v_pricing.list_price, 0);

  INSERT INTO public.enrollments (
    student_user_id,
    course_id,
    batch_id,
    pricing_id,
    enrollment_status,
    access_status,
    list_price,
    net_amount,
    paid_amount,
    due_amount
  )
  VALUES (
    p_student_user_id,
    v_batch.course_id,
    p_batch_id,
    v_pricing.id,
    'active',
    'active',
    COALESCE(v_pricing.list_price, 0),
    v_net_amount,
    0,
    v_net_amount
  )
  RETURNING *
  INTO v_enrollment;

  RETURN v_enrollment;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_student_to_batch(UUID, UUID) TO authenticated;
