module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  const keyId = process.env.RAZORPAY_KEY_ID;
  if (!keyId) {
    return res.status(500).json({ error: 'Razorpay not configured' });
  }

  return res.status(200).json({ key_id: keyId });
};
