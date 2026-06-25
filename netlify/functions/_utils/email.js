const RESEND_API_KEY = process.env.RESEND_API_KEY;
const FROM_EMAIL = process.env.FROM_EMAIL || 'SkillUpNow <payments@skillupnow.in>';

async function sendPaymentEmail(to, subject, htmlBody) {
  if (!RESEND_API_KEY) {
    console.warn('RESEND_API_KEY not set — skipping email to', to);
    return null;
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [to],
        subject,
        html: htmlBody,
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      console.error('Email send failed:', data);
      return null;
    }
    return data;
  } catch (err) {
    console.error('Email error:', err);
    return null;
  }
}

function buildSuccessEmail({ studentName, courseName, amount, paymentId, paidAt }) {
  const date = new Date(paidAt).toLocaleDateString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
  });
  const formattedAmt = '₹' + Number(amount).toLocaleString('en-IN');

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f0ff;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:32px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(68,25,152,.1)">
  <tr><td style="background:linear-gradient(135deg,#441998,#7c3aed);padding:28px 32px;text-align:center">
    <h1 style="margin:0;color:#fff;font-size:22px">Payment Confirmed</h1>
    <p style="margin:6px 0 0;color:rgba(255,255,255,.8);font-size:14px">Your enrollment is now active!</p>
  </td></tr>
  <tr><td style="padding:28px 32px">
    <p style="margin:0 0 18px;color:#333;font-size:15px">Hi <strong>${studentName || 'Student'}</strong>,</p>
    <p style="margin:0 0 22px;color:#555;font-size:14px;line-height:1.6">
      Your payment for <strong>${courseName}</strong> has been successfully processed. Your course access is now active.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9f7ff;border:1px solid #e8e0ff;border-radius:8px;margin-bottom:22px">
      <tr><td style="padding:16px 20px;border-bottom:1px solid #e8e0ff">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Amount Paid</span><br>
        <strong style="color:#441998;font-size:20px">${formattedAmt}</strong>
      </td><td style="padding:16px 20px;border-bottom:1px solid #e8e0ff;text-align:right">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Date</span><br>
        <strong style="color:#333;font-size:14px">${date}</strong>
      </td></tr>
      <tr><td colspan="2" style="padding:12px 20px">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Transaction ID</span><br>
        <code style="color:#7c3aed;font-size:13px">${paymentId}</code>
      </td></tr>
    </table>
    <p style="margin:0 0 8px;color:#555;font-size:13px;line-height:1.5">
      You can view your invoice and course materials from your <strong>Profile → Payments</strong> section.
    </p>
  </td></tr>
  <tr><td style="padding:16px 32px;background:#faf8ff;border-top:1px solid #f0ecff;text-align:center">
    <p style="margin:0;color:#999;font-size:12px">SkillUpNow · skillupnow.in · support@skillupnow.in</p>
  </td></tr>
</table>
</body></html>`;
}

function buildPendingEmail({ studentName, courseName, amount, orderId }) {
  const formattedAmt = '₹' + Number(amount).toLocaleString('en-IN');

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f0ff;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:32px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(68,25,152,.1)">
  <tr><td style="background:linear-gradient(135deg,#b45309,#f59e0b);padding:28px 32px;text-align:center">
    <h1 style="margin:0;color:#fff;font-size:22px">Payment Processing</h1>
    <p style="margin:6px 0 0;color:rgba(255,255,255,.85);font-size:14px">We're verifying your payment</p>
  </td></tr>
  <tr><td style="padding:28px 32px">
    <p style="margin:0 0 18px;color:#333;font-size:15px">Hi <strong>${studentName || 'Student'}</strong>,</p>
    <p style="margin:0 0 22px;color:#555;font-size:14px;line-height:1.6">
      Your payment of <strong>${formattedAmt}</strong> for <strong>${courseName}</strong> is being processed. This usually completes within <strong>24–48 hours</strong>.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fffbeb;border:1px solid #fde68a;border-radius:8px;margin-bottom:22px">
      <tr><td style="padding:16px 20px">
        <span style="color:#92400e;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Amount</span><br>
        <strong style="color:#b45309;font-size:20px">${formattedAmt}</strong>
      </td><td style="padding:16px 20px;text-align:right">
        <span style="color:#92400e;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Status</span><br>
        <strong style="color:#b45309;font-size:14px">⏳ Processing</strong>
      </td></tr>
      ${orderId ? `<tr><td colspan="2" style="padding:8px 20px 14px;border-top:1px solid #fde68a">
        <span style="color:#92400e;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Order Ref</span><br>
        <code style="color:#b45309;font-size:13px">${orderId}</code>
      </td></tr>` : ''}
    </table>
    <p style="margin:0 0 8px;color:#555;font-size:13px;line-height:1.5">
      We'll send you a confirmation email once the payment is verified. If you don't hear from us within 48 hours, please contact support.
    </p>
  </td></tr>
  <tr><td style="padding:16px 32px;background:#faf8ff;border-top:1px solid #f0ecff;text-align:center">
    <p style="margin:0;color:#999;font-size:12px">SkillUpNow · skillupnow.in · support@skillupnow.in</p>
  </td></tr>
</table>
</body></html>`;
}

module.exports = { sendPaymentEmail, buildSuccessEmail, buildPendingEmail };
