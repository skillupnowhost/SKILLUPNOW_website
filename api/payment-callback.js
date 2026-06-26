module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') return res.status(200).end();

  const enrollment = req.query.enrollment || '';

  let body = req.body || {};
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      body = Object.fromEntries(new URLSearchParams(body));
    }
  }

  const razorpay_payment_id = body.razorpay_payment_id || req.query.razorpay_payment_id || '';
  const razorpay_order_id = body.razorpay_order_id || req.query.razorpay_order_id || '';
  const razorpay_signature = body.razorpay_signature || req.query.razorpay_signature || '';

  if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
    return res.redirect(302, `/payment?enrollment=${enrollment}&payment_error=missing_fields`);
  }

  const params = new URLSearchParams({
    enrollment,
    razorpay_payment_id,
    razorpay_order_id,
    razorpay_signature,
  });

  return res.redirect(302, `/payment?${params.toString()}`);
};
