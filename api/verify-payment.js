const crypto = require('crypto');
const { insertRow, updateRows, selectRows } = require('./_utils/supabase');
const { sendPaymentEmail, buildSuccessEmail } = require('./_utils/email');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
  if (!KEY_SECRET) {
    return res.status(500).json({ error: 'Razorpay secret not configured' });
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
  } = req.body || {};

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ success: false, error: 'Missing payment fields' });
  }

  if (!enrollment_id || !course_id || !user_id || !amount) {
    return res.status(400).json({ success: false, error: 'Missing enrollment/payment details' });
  }

  // 1. Verify Razorpay signature
  const body = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expected = crypto
    .createHmac('sha256', KEY_SECRET)
    .update(body)
    .digest('hex');

  if (expected !== razorpay_signature) {
    return res.status(400).json({ success: false, error: 'Payment signature mismatch' });
  }

  try {
    // 2. Record payment in Supabase
    const paymentRecord = await insertRow('payments', {
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

    // 3. Update enrollment status
    const enrollments = await selectRows('enrollments', { id: enrollment_id });
    const enrollment = enrollments[0];
    if (enrollment) {
      const newPaid = (Number(enrollment.paid_amount) || 0) + Number(amount);
      const newDue = Math.max(0, (Number(enrollment.due_amount) || 0) - Number(amount));
      const updateData = {
        paid_amount: newPaid,
        due_amount: newDue,
      };
      if (newDue <= 0) {
        updateData.enrollment_status = 'active';
        updateData.access_status = 'active';
        updateData.activated_at = new Date().toISOString();
      }
      await updateRows('enrollments', { id: enrollment_id }, updateData);
    }

    // 4. Send success email (non-blocking)
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

    return res.status(200).json({
      success: true,
      payment_id: paymentRecord?.id || null,
      razorpay_payment_id,
      razorpay_order_id,
    });
  } catch (err) {
    console.error('verify-payment error:', err);
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' });
  }
};
