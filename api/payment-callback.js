module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') return res.status(200).end();

  const {
    razorpay_payment_id,
    razorpay_order_id,
    razorpay_signature,
  } = req.body || {};

  const enrollment = req.query.enrollment || '';

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
