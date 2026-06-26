class PaymentProcessor {
  constructor() {
    this.keyId = null;
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;
    try {
      const res = await fetch('/api/payment-config');
      if (!res.ok) throw new Error('Failed to load payment config');
      const data = await res.json();
      this.keyId = data.key_id;
      this.initialized = true;
    } catch (err) {
      console.error('PaymentProcessor init error:', err);
      throw new Error('Payment system unavailable. Please try again later.');
    }
  }

  async createOrder(amountPaise, receipt, notes) {
    await this.init();
    const res = await fetch('/api/create-razorpay-order', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: Math.round(amountPaise),
        currency: 'INR',
        receipt: (receipt || `rcpt_${Date.now()}`).slice(0, 40),
        notes: notes || {},
      }),
    });
    const order = await res.json();
    if (!res.ok) throw new Error(order.error || 'Order creation failed');
    return order;
  }

  openCheckout(order, { prefill, courseTitle, onSuccess, onDismiss, onFailure, callbackUrl }) {
    if (!this.keyId) throw new Error('PaymentProcessor not initialized');
    if (typeof window.Razorpay === 'undefined') {
      throw new Error('Razorpay SDK not loaded. Please refresh the page.');
    }

    const logoUrl = window.location.origin + '/icon/Logo.png';

    const options = {
      key: this.keyId,
      amount: order.amount,
      currency: order.currency || 'INR',
      order_id: order.id,
      name: 'SkillUpNow',
      description: courseTitle || 'Course Enrollment',
      image: logoUrl,
      prefill: {
        name: prefill?.name || '',
        email: prefill?.email || '',
        contact: prefill?.phone || '',
        method: 'upi',
      },
      notes: order.notes || {},
      theme: { color: '#7c5cfc' },
      retry: { enabled: true, max_count: 4 },
      modal: {
        ondismiss: () => {
          if (onDismiss) onDismiss();
        },
      },
    };

    if (callbackUrl) {
      options.callback_url = callbackUrl;
      options.redirect = true;
    } else {
      options.handler = (response) => {
        if (onSuccess) onSuccess(response);
      };
    }

    const rzp = new window.Razorpay(options);
    rzp.on('payment.failed', (response) => {
      const errMsg = response.error?.description || response.error?.reason || 'Payment was declined.';
      const is3dsError = errMsg && errMsg.toLowerCase().includes('3dsecure');
      const friendlyMsg = is3dsError
        ? 'Your card does not support 3D Secure. Please try UPI or Net Banking instead.'
        : errMsg;
      if (onFailure) onFailure(friendlyMsg, response);
    });
    rzp.open();
    return rzp;
  }

  async verifyPayment(razorpayResponse, enrollmentData) {
    let res;
    try {
      res = await fetch('/api/verify-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          razorpay_order_id: razorpayResponse.razorpay_order_id,
          razorpay_payment_id: razorpayResponse.razorpay_payment_id,
          razorpay_signature: razorpayResponse.razorpay_signature,
          enrollment_id: enrollmentData.enrollment_id,
          course_id: enrollmentData.course_id,
          user_id: enrollmentData.user_id,
          amount: enrollmentData.amount,
          payment_schedule_id: enrollmentData.payment_schedule_id || null,
          user_email: enrollmentData.user_email || '',
          user_name: enrollmentData.user_name || '',
          course_name: enrollmentData.course_name || '',
        }),
      });
    } catch (networkErr) {
      throw new Error('Network error — please check your internet connection and try again.');
    }

    let data;
    try {
      data = await res.json();
    } catch {
      throw new Error(`Server returned status ${res.status} with non-JSON response.`);
    }

    if (!res.ok || !data.success) {
      throw new Error(data.error || `Verification failed (HTTP ${res.status})`);
    }
    return data;
  }

  async sendNotification(paymentData) {
    try {
      await fetch('/api/notify-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(paymentData),
      });
    } catch (err) {
      console.warn('Notification send failed:', err);
    }
  }

  formatAmount(amount) {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      minimumFractionDigits: 0,
    }).format(amount);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  window.paymentProcessor = new PaymentProcessor();
});
