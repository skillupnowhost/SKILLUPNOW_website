exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, body: '' };
  }

  let body = {};
  try {
    if (event.headers['content-type']?.includes('application/x-www-form-urlencoded')) {
      body = Object.fromEntries(new URLSearchParams(event.body || ''));
    } else {
      body = JSON.parse(event.body || '{}');
    }
  } catch {
    body = {};
  }

  const {
    razorpay_payment_id,
    razorpay_order_id,
    razorpay_signature,
  } = body;

  const qs = event.queryStringParameters || {};
  const enrollment = qs.enrollment || '';

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
