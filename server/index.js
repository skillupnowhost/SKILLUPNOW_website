require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const paymentRoutes = require('./routes/payment');

const app  = express();
const PORT = process.env.PORT || 5000;

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : ['http://localhost:3000', 'http://127.0.0.1:5500', 'https://skillupnowadmin.org'],
  methods: ['GET', 'POST'],
  credentials: true,
}));

// Raw body for Razorpay webhook signature verification
app.use('/api/payment/webhook', express.raw({ type: 'application/json' }));

app.use(express.json());

app.get('/health', (_req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

app.use('/api/payment', paymentRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ success: false, error: err.message || 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`SkillUpNow Payment API running on port ${PORT}`);
});
