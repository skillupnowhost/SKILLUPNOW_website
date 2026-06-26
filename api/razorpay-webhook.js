const crypto = require('crypto');
const { updateRows, selectRows } = require('./_utils/supabase');
const { sendPaymentEmail, buildSuccessEmail, buildPendingEmail, sendAdminNotification } = require('./_utils/email');

function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

  try {
    const rawBody = await getRawBody(req);
    const receivedSig = req.headers['x-razorpay-signature'];

    // Verify webhook signature
    if (WEBHOOK_SECRET && receivedSig) {
      const expected = crypto
        .createHmac('sha256', WEBHOOK_SECRET)
        .update(rawBody)
        .digest('hex');

      if (expected !== receivedSig) {
        console.warn('Webhook signature mismatch');
        return res.status(400).json({ error: 'Invalid webhook signature' });
      }
    }

    const event = JSON.parse(rawBody.toString());
    const eventType = event.event;
    const payload = event.payload;

    console.log('Razorpay webhook:', eventType);

    switch (eventType) {
      case 'payment.captured': {
        const payment = payload.payment.entity;
        await handlePaymentCaptured(payment);
        break;
      }
      case 'payment.authorized': {
        const payment = payload.payment.entity;
        await handlePaymentAuthorized(payment);
        break;
      }
      case 'payment.failed': {
        const payment = payload.payment.entity;
        await handlePaymentFailed(payment);
        break;
      }
      case 'order.paid': {
        const order = payload.order.entity;
        console.log('Order paid:', order.id);
        break;
      }
      default:
        console.log('Unhandled webhook event:', eventType);
    }

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('Webhook error:', err);
    return res.status(500).json({ error: 'Webhook processing failed' });
  }
}

async function handlePaymentCaptured(payment) {
  const paymentId = payment.id;
  const orderId = payment.order_id;
  const amountRupees = payment.amount / 100;
  const email = payment.email;
  const contact = payment.contact;
  const notes = payment.notes || {};

  console.log('Payment captured:', paymentId, '₹', amountRupees);

  // Update existing payment record if found
  try {
    const existing = await selectRows('payments', { gateway_payment_id: paymentId });
    if (existing.length > 0 && existing[0].payment_status === 'completed') {
      return; // Already processed
    }

    if (existing.length > 0) {
      await updateRows('payments', { gateway_payment_id: paymentId }, {
        payment_status: 'completed',
        paid_at: new Date().toISOString(),
      });

      // Update enrollment if we have the enrollment_id
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

  // Send success email
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

  // Check if we already have this payment recorded
  try {
    const existing = await selectRows('payments', { gateway_payment_id: paymentId });
    if (existing.length > 0) return; // Already tracked
  } catch (err) {
    // No existing record — that's fine for pending
  }

  // Send pending email
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

module.exports = handler;
module.exports.config = {
  api: { bodyParser: false },
};
