const { selectRows } = require('./_utils/supabase');
const { sendPaymentEmail, buildSuccessEmail, buildPendingEmail } = require('./_utils/email');

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

  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Invalid JSON body' }),
    };
  }

  const {
    payment_id,
    user_email,
    user_name,
    course_name,
    amount,
    status,
    order_id,
  } = body;

  if (!payment_id || !user_email) {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'payment_id and user_email are required' }),
    };
  }

  try {
    const payments = await selectRows('payments', { id: payment_id });
    if (payments.length === 0) {
      return {
        statusCode: 404,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Payment not found' }),
      };
    }
  } catch (err) {
    return {
      statusCode: 404,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Payment not found' }),
    };
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

  if (!result) {
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Email sending failed or not configured' }),
    };
  }

  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({ success: true }),
  };
};
