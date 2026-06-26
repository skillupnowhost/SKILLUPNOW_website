const crypto = require('crypto');

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

  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
  if (!KEY_SECRET) {
    console.error('RAZORPAY_KEY_SECRET not configured');
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Payment gateway not configured. Please contact support.' }),
    };
  }

  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Invalid JSON body' }),
    };
  }

  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = body;

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Missing payment fields' }),
    };
  }

  // Verify Razorpay signature
  const sigBody = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expected = crypto
    .createHmac('sha256', KEY_SECRET)
    .update(sigBody)
    .digest('hex');

  if (expected !== razorpay_signature) {
    console.error('Signature mismatch', { razorpay_order_id, razorpay_payment_id });
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: false, error: 'Payment signature mismatch' }),
    };
  }

  // Signature is valid — tell the frontend to save the record client-side
  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      success: true,
      verified: true,
      razorpay_payment_id,
      razorpay_order_id,
    }),
  };
};
