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

  async verifyPayment(razorpayResponse, enrollmentData, supabaseClient) {
    // Step 1: Verify signature server-side
    let res;
    try {
      res = await fetch('/api/verify-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          razorpay_order_id: razorpayResponse.razorpay_order_id,
          razorpay_payment_id: razorpayResponse.razorpay_payment_id,
          razorpay_signature: razorpayResponse.razorpay_signature,
        }),
      });
    } catch (networkErr) {
      throw new Error('Network error — please check your internet connection and try again.');
    }

    let sigResult;
    try {
      sigResult = await res.json();
    } catch {
      throw new Error(`Server returned status ${res.status} with non-JSON response.`);
    }

    if (!res.ok || !sigResult.success) {
      throw new Error(sigResult.error || `Signature verification failed (HTTP ${res.status})`);
    }

    // Step 2: Save payment record client-side using authenticated Supabase client
    const client = supabaseClient || window.supabaseConfig?.client;
    if (!client) {
      throw new Error('Database client not available. Please refresh and try again.');
    }

    // Check if payment already recorded (idempotency)
    const { data: existing } = await client
      .from('payments')
      .select('id')
      .eq('gateway_payment_id', razorpayResponse.razorpay_payment_id)
      .maybeSingle();

    if (existing) {
      return { success: true, payment_id: existing.id, already_recorded: true };
    }

    // Insert payment record
    const { data: paymentRecord, error: insertErr } = await client
      .from('payments')
      .insert({
        student_user_id: enrollmentData.user_id,
        course_id: enrollmentData.course_id,
        enrollment_id: enrollmentData.enrollment_id,
        payment_schedule_id: enrollmentData.payment_schedule_id || null,
        amount: Number(enrollmentData.amount),
        payment_method: 'gateway_link',
        payment_gateway: 'razorpay',
        payment_status: 'completed',
        paid_at: new Date().toISOString(),
        transaction_reference: razorpayResponse.razorpay_payment_id,
        gateway_payment_id: razorpayResponse.razorpay_payment_id,
        gateway_order_id: razorpayResponse.razorpay_order_id,
        gateway_signature: razorpayResponse.razorpay_signature,
      })
      .select('id')
      .single();

    if (insertErr) {
      console.error('Payment insert error:', insertErr);
      throw new Error('Payment verified but record save failed: ' + (insertErr.message || 'Database error'));
    }

    // Step 3: Update enrollment (non-blocking)
    try {
      const { data: enrollment } = await client
        .from('enrollments')
        .select('paid_amount, due_amount')
        .eq('id', enrollmentData.enrollment_id)
        .single();

      if (enrollment) {
        const newPaid = (Number(enrollment.paid_amount) || 0) + Number(enrollmentData.amount);
        const newDue = Math.max(0, (Number(enrollment.due_amount) || 0) - Number(enrollmentData.amount));
        const updateData = { paid_amount: newPaid, due_amount: newDue };
        if (newDue <= 0) {
          updateData.enrollment_status = 'active';
          updateData.access_status = 'active';
          updateData.activated_at = new Date().toISOString();
        }
        await client.from('enrollments').update(updateData).eq('id', enrollmentData.enrollment_id);
      }
    } catch (enrollErr) {
      console.warn('Enrollment update failed (non-fatal):', enrollErr);
    }

    // Step 4: Send email notification (non-blocking)
    this.sendNotification({
      payment_id: paymentRecord?.id,
      user_email: enrollmentData.user_email,
      user_name: enrollmentData.user_name,
      course_name: enrollmentData.course_name,
      amount: enrollmentData.amount,
      status: 'completed',
    });

    return {
      success: true,
      payment_id: paymentRecord?.id || null,
      razorpay_payment_id: razorpayResponse.razorpay_payment_id,
      razorpay_order_id: razorpayResponse.razorpay_order_id,
    };
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
