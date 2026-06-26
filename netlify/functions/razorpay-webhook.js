const crypto = require('crypto');
const { updateRows, selectRows } = require('./_utils/supabase');
const { sendPaymentEmail, buildSuccessEmail, buildPendingEmail, sendAdminNotification } = require('./_utils/email');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: JSON.stringify({ error: 'Method not allowed' }) };
  }

  const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

  try {
    const rawBody = event.body;
    const receivedSig = event.headers['x-razorpay-signature'];

    if (WEBHOOK_SECRET && receivedSig) {
      const expected = crypto
        .createHmac('sha256', WEBHOOK_SECRET)
        .update(rawBody)
        .digest('hex');

      if (expected !== receivedSig) {
        console.warn('Webhook signature mismatch');
        return { statusCode: 400, body: JSON.stringify({ error: 'Invalid webhook signature' }) };
      }
    }

    const payload = JSON.parse(rawBody);
    const eventType = payload.event;

    console.log('Razorpay webhook:', eventType);

    switch (eventType) {
      case 'payment.captured':
        await handlePaymentCaptured(payload.payload.payment.entity);
        break;
      case 'payment.authorized':
        await handlePaymentAuthorized(payload.payload.payment.entity);
        break;
      case 'payment.failed':
        await handlePaymentFailed(payload.payload.payment.entity);
        break;
      case 'order.paid':
        console.log('Order paid:', payload.payload.order.entity.id);
        break;
      default:
        console.log('Unhandled webhook event:', eventType);
    }

    return { statusCode: 200, body: JSON.stringify({ success: true }) };
  } catch (err) {
    console.error('Webhook error:', err);
    return { statusCode: 500, body: JSON.stringify({ error: 'Webhook processing failed' }) };
  }
};

async function handlePaymentCaptured(payment) {
  const paymentId = payment.id;
  const orderId = payment.order_id;
  const amountRupees = payment.amount / 100;
  const email = payment.email;
  const notes = payment.notes || {};

  console.log('Payment captured:', paymentId, '₹', amountRupees);

  try {
    const existing = await selectRows('payments', { gateway_payment_id: paymentId });
    if (existing.length > 0 && existing[0].payment_status === 'completed') {
      return;
    }

    if (existing.length > 0) {
      await updateRows('payments', { gateway_payment_id: paymentId }, {
        payment_status: 'completed',
        paid_at: new Date().toISOString(),
      });

      const enrollmentId = existing[0].enrollment_id;
      if (enrollmentId) {
        const enrollments = await selectRows('enrollments', { id: enrollmentId });
        if (enrollments.length > 0) {
          const enrollment = enrollments[0];
          const newPaid = (Number(enrollment.paid_amount) || 0) + amountRupees;
          const newDue = Math.max(0, (Number(enrollment.due_amount) || 0) - amountRupees);
          const updateData = { paid_amount: newPaid, due_amount: newDue };
          if (newDue <= 0) {
            updateData.enrollment_status = 'active';
            updateData.access_status = 'active';
            updateData.activated_at = new Date().toISOString();
          }
          await updateRows('enrollments', { id: enrollmentId }, updateData);
        }
      }
    }
  } catch (err) {
    console.error('Error updating payment on capture:', err);
  }

  if (email) {
    try {
      const courseName = notes.course_name || 'Course Enrollment';
      const studentName = notes.student_name || '';
      const emailHtml = buildSuccessEmail({
        studentName,
        courseName,
        amount: amountRupees,
        paymentId,
        paidAt: new Date().toISOString(),
      });
      await sendPaymentEmail(email, 'Payment Confirmed — SkillUpNow', emailHtml);
    } catch (err) {
      console.error('Email send error on capture:', err);
    }
  }

  // Notify admin
  sendAdminNotification({
    studentName: notes.student_name || '',
    studentEmail: email || '',
    courseName: notes.course_name || 'Course Enrollment',
    amount: amountRupees,
    paymentId,
    paymentMethod: 'gateway_link',
    status: 'completed',
    paidAt: new Date().toISOString(),
  }).catch(() => {});
}

async function handlePaymentAuthorized(payment) {
  const paymentId = payment.id;
  const amountRupees = payment.amount / 100;
  const email = payment.email;
  const notes = payment.notes || {};

  console.log('Payment authorized (pending capture):', paymentId, '₹', amountRupees);

  try {
    const existing = await selectRows('payments', { gateway_payment_id: paymentId });
    if (existing.length > 0) return;
  } catch (err) {
    // No existing record — fine for pending
  }

  if (email) {
    try {
      const courseName = notes.course_name || 'Course Enrollment';
      const studentName = notes.student_name || '';
      const emailHtml = buildPendingEmail({
        studentName,
        courseName,
        amount: amountRupees,
        orderId: payment.order_id,
      });
      await sendPaymentEmail(email, 'Payment Processing — SkillUpNow', emailHtml);
    } catch (err) {
      console.error('Email send error on authorized:', err);
    }
  }
}

async function handlePaymentFailed(payment) {
  const paymentId = payment.id;
  console.log('Payment failed:', paymentId, payment.error_description || payment.error_reason);

  try {
    const existing = await selectRows('payments', { gateway_payment_id: paymentId });
    if (existing.length > 0) {
      await updateRows('payments', { gateway_payment_id: paymentId }, {
        payment_status: 'failed',
      });
    }
  } catch (err) {
    console.error('Error updating failed payment:', err);
  }
}
