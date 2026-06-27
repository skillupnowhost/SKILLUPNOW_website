const RESEND_API_KEY = process.env.RESEND_API_KEY;
const FROM_EMAIL = process.env.FROM_EMAIL || 'SkillUpNow <notifications@skillupnow.in>';

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { studentName, studentEmail, moduleName, internshipName, deadline, gitPushLink } = req.body || {};

  if (!studentEmail || !moduleName) {
    return res.status(400).json({ error: 'studentEmail and moduleName are required' });
  }

  if (!RESEND_API_KEY) {
    console.warn('RESEND_API_KEY not set — skipping module assignment email');
    return res.status(200).json({ success: true, skipped: true });
  }

  const deadlineStr = deadline
    ? new Date(deadline).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
    : null;

  const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f0ff;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:32px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(68,25,152,.1)">
  <tr><td style="background:linear-gradient(135deg,#7c3aed,#6d28d9);padding:28px 32px;text-align:center">
    <h1 style="margin:0;color:#fff;font-size:22px">New Module Assigned</h1>
    <p style="margin:6px 0 0;color:rgba(255,255,255,.8);font-size:14px">${internshipName || 'Internship'}</p>
  </td></tr>
  <tr><td style="padding:28px 32px">
    <p style="margin:0 0 18px;color:#333;font-size:15px">Hi <strong>${studentName || 'Student'}</strong>,</p>
    <p style="margin:0 0 22px;color:#555;font-size:14px;line-height:1.6">
      You have been assigned a new module for your internship. Please log in to your dashboard to start working on it.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9f7ff;border:1px solid #e8e0ff;border-radius:8px;margin-bottom:22px">
      <tr><td style="padding:16px 20px;border-bottom:1px solid #e8e0ff">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Module</span><br>
        <strong style="color:#7c3aed;font-size:16px">${moduleName}</strong>
      </td></tr>
      <tr><td style="padding:16px 20px;border-bottom:1px solid #e8e0ff">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Internship</span><br>
        <strong style="color:#333;font-size:14px">${internshipName || '—'}</strong>
      </td></tr>
      ${deadlineStr ? `<tr><td style="padding:16px 20px;border-bottom:1px solid #e8e0ff">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Deadline</span><br>
        <strong style="color:#333;font-size:14px">${deadlineStr}</strong>
      </td></tr>` : ''}
      ${gitPushLink ? `<tr><td style="padding:16px 20px">
        <span style="color:#888;font-size:12px;text-transform:uppercase;letter-spacing:.5px">Git Repository</span><br>
        <a href="${gitPushLink}" style="color:#7c3aed;font-size:13px;text-decoration:underline">${gitPushLink}</a>
      </td></tr>` : ''}
    </table>
    <p style="margin:0 0 16px;color:#555;font-size:13px;line-height:1.5">
      Log in to your <strong>Intern Dashboard</strong> to view the full details and start working on this module.
    </p>
    <div style="text-align:center;margin:24px 0 8px">
      <a href="https://skillupnow.in/pages/intern-dashboard.html" style="display:inline-block;padding:12px 32px;background:linear-gradient(135deg,#7c3aed,#6d28d9);color:#fff;border-radius:8px;text-decoration:none;font-weight:700;font-size:14px;box-shadow:0 4px 12px rgba(124,58,237,.35)">Open Dashboard</a>
    </div>
  </td></tr>
  <tr><td style="padding:16px 32px;background:#faf8ff;border-top:1px solid #f0ecff;text-align:center">
    <p style="margin:0;color:#999;font-size:12px">SkillUpNow &middot; skillupnow.in &middot; support@skillupnow.in</p>
  </td></tr>
</table>
</body></html>`;

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [studentEmail],
        subject: `New Module Assigned: ${moduleName} — ${internshipName || 'SkillUpNow'}`,
        html,
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      console.error('Module assignment email failed:', data);
      return res.status(500).json({ error: 'Email send failed', details: data });
    }

    return res.status(200).json({ success: true, data });
  } catch (err) {
    console.error('Module assignment email error:', err);
    return res.status(500).json({ error: err.message });
  }
};
