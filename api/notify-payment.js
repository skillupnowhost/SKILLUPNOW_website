const { selectRows } = require('./_utils/supabase');
const { sendPaymentEmail, buildSuccessEmail, buildPendingEmail, sendAdminNotification } = require('./_utils/email');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const {
    payment_id,
    user_email,
    user_name,
    course_name,
    amount,
    status,
    order_id,
  } = req.body || {};

  if (!payment_id || !user_email) {
    return res.status(400).json({ error: 'payment_id and user_email are required' });
  }

  // Verify the payment exists in Supabase
  try {
    const payments = await selectRows('payments', { id: payment_id });
    if (payments.length === 0) {
      return res.status(404).json({ error: 'Payment not found' });
    }
  } catch (err) {
    return res.status(404).json({ error: 'Payment not found' });
  }

  const paymentStatus = status || 'pending';
  let subject, htmlBody;

  if (paymentStatus === 'completed') {
    subject = 'Payment Confirmed — SkillUpNow';
    htmlBody = buildSuccessEmail({
      studentName: user_name,
      courseName: course_name || 'Course Enrollment',
      amount: Number(amount),
      paymentId: payment_id,
      paidAt: new Date().toISOString(),
    });
  } else {
    subject = 'Payment Processing — SkillUpNow';
    htmlBody = buildPendingEmail({
      studentName: user_name,
      courseName: course_name || 'Course Enrollment',
      amount: Number(amount),
      orderId: order_id,
    });
  }

  const result = await sendPaymentEmail(user_email, subject, htmlBody);

  // Notify admin about new payment (non-blocking)
  sendAdminNotification({
    studentName: user_name,
    studentEmail: user_email,
    courseName: course_name || 'Course Enrollment',
    amount: Number(amount),
    paymentId: payment_id,
    paymentMethod: paymentStatus === 'completed' ? 'gateway_link' : 'manual',
    status: paymentStatus,
  }).catch(() => {});

  if (!result) {
    return res.status(500).json({ error: 'Email sending failed or not configured' });
  }

  return res.status(200).json({ success: true });
};
