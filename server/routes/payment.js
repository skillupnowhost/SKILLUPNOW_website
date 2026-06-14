const express   = require('express');
const Razorpay  = require('razorpay');
const crypto    = require('crypto');

const router = express.Router();

const razorpay = new Razorpay({
  key_id:     process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// ─── POST /api/payment/create-order ─────────────────────────────────────────
// Creates a Razorpay order server-side before opening the checkout modal.
// Body: { amount (in rupees), currency?, receipt?, notes? }
router.post('/create-order', async (req, res) => {
  try {
    const { amount, currency = 'INR', receipt, notes = {} } = req.body;

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ success: false, error: 'Invalid amount' });
    }

    const options = {
      amount:   Math.round(Number(amount) * 100), // convert ₹ → paise
      currency,
      receipt:  receipt || `rcpt_${Date.now()}`,
      notes,
    };

    const order = await razorpay.orders.create(options);

    res.json({
      success:   true,
      orderId:   order.id,
      amount:    order.amount,
      currency:  order.currency,
      receipt:   order.receipt,
    });
  } catch (err) {
    console.error('create-order error:', err);
    res.status(500).json({ success: false, error: err.error?.description || err.message });
  }
});

// ─── POST /api/payment/verify ────────────────────────────────────────────────
// Verifies the Razorpay payment signature after checkout modal success.
// Body: { razorpay_order_id, razorpay_payment_id, razorpay_signature }
router.post('/verify', (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({ success: false, error: 'Missing payment fields' });
    }

    const body      = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expected  = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest('hex');

    if (expected !== razorpay_signature) {
      return res.status(400).json({ success: false, error: 'Payment signature mismatch' });
    }

    res.json({ success: true, paymentId: razorpay_payment_id, orderId: razorpay_order_id });
  } catch (err) {
    console.error('verify error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── POST /api/payment/webhook ───────────────────────────────────────────────
// Receives Razorpay webhook events (payment.captured, payment.failed, refund.created…).
// Set this URL in Razorpay Dashboard → Settings → Webhooks.
// Set Webhook Secret in .env as RAZORPAY_WEBHOOK_SECRET.
router.post('/webhook', (req, res) => {
  try {
    const receivedSig = req.headers['x-razorpay-signature'];
    const secret      = process.env.RAZORPAY_WEBHOOK_SECRET;

    if (secret) {
      const expected = crypto
        .createHmac('sha256', secret)
        .update(req.body) // raw buffer (set in index.js)
        .digest('hex');

      if (expected !== receivedSig) {
        console.warn('Webhook signature mismatch');
        return res.status(400).json({ success: false, error: 'Invalid webhook signature' });
      }
    }

    const event   = JSON.parse(req.body.toString());
    const payload = event.payload;

    console.log('Razorpay webhook event:', event.event);

    switch (event.event) {
      case 'payment.captured': {
        const payment = payload.payment.entity;
        console.log('Payment captured:', payment.id, '₹', payment.amount / 100);
        // TODO: mark enrollment active in your DB using payment.notes.enrollment_id
        break;
      }
      case 'payment.failed': {
        const payment = payload.payment.entity;
        console.log('Payment failed:', payment.id, payment.error_description);
        // TODO: notify student or log failure
        break;
      }
      case 'refund.created': {
        const refund = payload.refund.entity;
        console.log('Refund created:', refund.id, '₹', refund.amount / 100);
        // TODO: update payment record in DB
        break;
      }
      case 'refund.processed': {
        const refund = payload.refund.entity;
        console.log('Refund processed:', refund.id);
        break;
      }
      default:
        console.log('Unhandled event:', event.event);
    }

    res.json({ success: true });
  } catch (err) {
    console.error('webhook error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── POST /api/payment/refund ─────────────────────────────────────────────────
// Initiates a full or partial refund for a captured payment.
// Body: { paymentId, amount? (in rupees, omit for full refund), notes? }
router.post('/refund', async (req, res) => {
  try {
    const { paymentId, amount, notes = {} } = req.body;

    if (!paymentId) {
      return res.status(400).json({ success: false, error: 'paymentId is required' });
    }

    const options = { notes };
    if (amount) options.amount = Math.round(Number(amount) * 100); // partial refund in paise

    const refund = await razorpay.payments.refund(paymentId, options);

    res.json({
      success:   true,
      refundId:  refund.id,
      paymentId: refund.payment_id,
      amount:    refund.amount / 100,
      status:    refund.status,
    });
  } catch (err) {
    console.error('refund error:', err);
    res.status(500).json({ success: false, error: err.error?.description || err.message });
  }
});

// ─── GET /api/payment/order/:orderId ─────────────────────────────────────────
// Fetch Razorpay order details (useful for status checks).
router.get('/order/:orderId', async (req, res) => {
  try {
    const order = await razorpay.orders.fetch(req.params.orderId);
    res.json({ success: true, order });
  } catch (err) {
    console.error('fetch-order error:', err);
    res.status(500).json({ success: false, error: err.error?.description || err.message });
  }
});

// ─── GET /api/payment/:paymentId ──────────────────────────────────────────────
// Fetch a single payment's details from Razorpay.
router.get('/:paymentId', async (req, res) => {
  try {
    const payment = await razorpay.payments.fetch(req.params.paymentId);
    res.json({ success: true, payment });
  } catch (err) {
    console.error('fetch-payment error:', err);
    res.status(500).json({ success: false, error: err.error?.description || err.message });
  }
});

module.exports = router;
