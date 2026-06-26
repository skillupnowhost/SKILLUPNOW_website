exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, body: '' };
  }

  const qs = event.queryStringParameters || {};
  const enrollment = qs.enrollment || '';

  let rawBody = event.body || '';
  if (event.isBase64Encoded) {
    rawBody = Buffer.from(rawBody, 'base64').toString('utf-8');
  }

  let body = {};
  try {
    body = JSON.parse(rawBody);
  } catch {
    if (rawBody) {
      body = Object.fromEntries(new URLSearchParams(rawBody));
    }
  }

  const razorpay_payment_id = body.razorpay_payment_id || qs.razorpay_payment_id || '';
  const razorpay_order_id = body.razorpay_order_id || qs.razorpay_order_id || '';
  const razorpay_signature = body.razorpay_signature || qs.razorpay_signature || '';

  if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
    return {
      statusCode: 302,
      headers: { Location: `/payment?enrollment=${enrollment}&payment_error=missing_fields` },
      body: '',
    };
  }

  const params = new URLSearchParams({
    enrollment,
    razorpay_payment_id,
    razorpay_order_id,
    razorpay_signature,
  });

  return {
    statusCode: 302,
    headers: { Location: `/payment?${params.toString()}` },
    body: '',
  };
};
