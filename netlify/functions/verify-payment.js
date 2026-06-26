const crypto = require('crypto');
const { insertRow, updateRows, selectRows } = require('./_utils/supabase');
const { sendPaymentEmail, buildSuccessEmail, sendAdminNotification } = require('./_utils/email');

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: CORS_HEADERS, body: '' };
  }
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
  if (!KEY_SECRET) {
    console.error('RAZORPAY_KEY_SECRET not configured');
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Payment gateway not configured. Please contact support.' }),
    };
  }

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured');
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Database not configured. Please contact support.' }),
    };
  }

  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Invalid JSON body' }),
    };
  }

  const {
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature,
    enrollment_id,
    course_id,
    user_id,
    amount,
    payment_schedule_id,
    user_email,
    user_name,
    course_name,
  } = body;

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Missing payment fields' }),
    };
  }

  if (!enrollment_id || !course_id || !user_id || !amount) {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Missing enrollment/payment details' }),
    };
  }

  // ── Step 1: Verify Razorpay signature ──────────────────────
  const sigBody = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expected = crypto
    .createHmac('sha256', KEY_SECRET)
    .update(sigBody)
    .digest('hex');

  if (expected !== razorpay_signature) {
    console.error('Signature mismatch', { razorpay_order_id, razorpay_payment_id });
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Payment signature mismatch — please contact support with your Transaction ID.' }),
    };
  }

  // ── Step 2: Idempotency check — return success if already recorded ──
  try {
    const existing = await selectRows('payments', { gateway_payment_id: razorpay_payment_id });
    if (existing.length > 0) {
      console.log('Payment already recorded:', razorpay_payment_id);
      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify({
          success: true,
          payment_id: existing[0].id,
          razorpay_payment_id,
          razorpay_order_id,
          already_recorded: true,
        }),
      };
    }
  } catch (err) {
    console.warn('Idempotency check failed (non-fatal):', err.message);
  }

  // ── Step 3: Insert payment record ──────────────────────────
  let paymentRecord;
  try {
    paymentRecord = await insertRow('payments', {
      student_user_id: user_id,
      course_id,
      enrollment_id,
      payment_schedule_id: payment_schedule_id || null,
      amount: Number(amount),
      payment_method: 'gateway_link',
      payment_gateway: 'razorpay',
      payment_status: 'completed',
      paid_at: new Date().toISOString(),
      transaction_reference: razorpay_payment_id,
      gateway_payment_id: razorpay_payment_id,
      gateway_order_id: razorpay_order_id,
      gateway_signature: razorpay_signature,
    });
  } catch (insertErr) {
    console.error('Payment insert error:', insertErr.message);

    // If insert fails due to unique constraint (duplicate), try to find existing
    if (insertErr.message && (insertErr.message.includes('duplicate') || insertErr.message.includes('unique') || insertErr.message.includes('already exists'))) {
      try {
        const existing = await selectRows('payments', { gateway_payment_id: razorpay_payment_id });
        if (existing.length > 0) {
          return {
            statusCode: 200,
            headers: CORS_HEADERS,
            body: JSON.stringify({
              success: true,
              payment_id: existing[0].id,
              razorpay_payment_id,
              razorpay_order_id,
              already_recorded: true,
            }),
          };
        }
      } catch (e) { /* fall through */ }
    }

    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        success: false,
        error: 'Payment verified but failed to save record: ' + (insertErr.message || 'Database error'),
        razorpay_payment_id,
      }),
    };
  }

  // ── Step 4: Update enrollment (non-blocking — don't fail verification) ──
  try {
    const enrollments = await selectRows('enrollments', { id: enrollment_id });
    const enrollment = enrollments[0];
    if (enrollment) {
      const newPaid = (Number(enrollment.paid_amount) || 0) + Number(amount);
      const newDue = Math.max(0, (Number(enrollment.due_amount) || 0) - Number(amount));
      const updateData = { paid_amount: newPaid, due_amount: newDue };
      if (newDue <= 0) {
        updateData.enrollment_status = 'active';
        updateData.access_status = 'active';
        updateData.activated_at = new Date().toISOString();
      }
      await updateRows('enrollments', { id: enrollment_id }, updateData);
    }
  } catch (enrollErr) {
    console.error('Enrollment update error (non-fatal):', enrollErr.message);
  }

  // ── Step 5: Send emails (non-blocking) ─────────────────────
  if (user_email) {
    const emailHtml = buildSuccessEmail({
      studentName: user_name,
      courseName: course_name || 'Course Enrollment',
      amount: Number(amount),
      paymentId: razorpay_payment_id,
      paidAt: new Date().toISOString(),
    });
    sendPaymentEmail(user_email, 'Payment Confirmed — SkillUpNow', emailHtml).catch(() => {});
  }

  sendAdminNotification({
    studentName: user_name,
    studentEmail: user_email,
    courseName: course_name || 'Course Enrollment',
    amount: Number(amount),
    paymentId: razorpay_payment_id,
    paymentMethod: 'gateway_link',
    status: 'completed',
    paidAt: new Date().toISOString(),
  }).catch(() => {});

  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      success: true,
      payment_id: paymentRecord?.id || null,
      razorpay_payment_id,
      razorpay_order_id,
    }),
  };
};
