/* ==========================================
   MAIN APPLICATION SCRIPT
   ========================================== */

class SkillUpNowApp {
  constructor() {
    this.currentUser = null;
    this.selectedCourses = [];
    this.cart = [];
    this.emiCalculators = {};
    this.init();
  }

  init() {
    this.setupCursor();
    this.setupModalFunctionality();
    this.setupFormValidation();
    this.setupScrollReveal();
    this.setupEventListeners();
    this.setupLazyLoading();
    this.checkUserSession();
  }

  // ==================== CUSTOM CURSOR ====================
  // Neural Pointer cursor is handled by js/neural-cursor.js
  setupCursor() {}

  // ==================== MODAL FUNCTIONALITY ====================
  setupModalFunctionality() {
    const modal = document.getElementById('mo');
    if (!modal) return;

    // Close modal on overlay click
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        this.closeModal();
      }
    });

    // Close modal on close button
    const closeBtn = modal.querySelector('.mcls');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => this.closeModal());
    }

    // ESC key to close modal
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && modal.classList.contains('open')) {
        this.closeModal();
      }
    });
  }

  openModal(type = 'login') {
    const modal = document.getElementById('mo');
    if (modal) {
      modal.classList.add('open');
      this.switchModalTab(type);
    }
  }

  closeModal() {
    const modal = document.getElementById('mo');
    if (modal) {
      modal.classList.remove('open');
    }
  }

  switchModalTab(tab) {
    const loginForm = document.getElementById('lf');
    const registerForm = document.getElementById('rf');
    const otpStep = document.getElementById('otp-step');
    const roleSelect = document.getElementById('rs');
    const adminForm = document.getElementById('af');

    // Hide all panels
    [loginForm, registerForm, otpStep, roleSelect, adminForm].forEach(el => {
      if (el) el.style.display = 'none';
    });

    if (tab === 'role-select' && roleSelect) {
      roleSelect.style.display = 'block';
    } else if (tab === 'login' && loginForm) {
      loginForm.style.display = 'block';
    } else if (tab === 'register' && registerForm) {
      registerForm.style.display = 'block';
    } else if (tab === 'admin' && adminForm) {
      adminForm.style.display = 'block';
    } else if (loginForm) {
      // Fallback: if role-select doesn't exist, show login
      if (!roleSelect) loginForm.style.display = 'block';
    }
  }

  // ==================== FORM VALIDATION ====================
  setupFormValidation() {
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
      new FormValidator(form);
    });
  }

  // ==================== SCROLL REVEAL ====================
  setupScrollReveal() {
    const revealElements = document.querySelectorAll('.reveal');

    const intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry, index) => {
        if (entry.isIntersecting) {
          setTimeout(() => {
            entry.target.classList.add('visible');
          }, index * 80);
          intersectionObserver.unobserve(entry.target);
        }
      });
    }, {
      threshold: 0.08,
      rootMargin: '0px 0px -40px 0px'
    });

    revealElements.forEach(el => intersectionObserver.observe(el));
  }

  // ==================== EVENT LISTENERS ====================
  setupEventListeners() {
    // Course filtering
    this.setupCourseFiltering();

    // Add to cart
    this.setupAddToCart();

    // Payment page link
    this.setupPaymentNavigation();
  }

  setupCourseFiltering() {
    const filterButtons = document.querySelectorAll('.ftab');
    const courseCards = document.querySelectorAll('.course-card');

    filterButtons.forEach(button => {
      button.addEventListener('click', () => {
        const category = button.dataset.filter || button.textContent.toLowerCase();

        filterButtons.forEach(btn => btn.classList.remove('active'));
        button.classList.add('active');

        courseCards.forEach(card => {
          const cardCategory = card.dataset.cat || card.textContent.toLowerCase();
          if (category === 'all' || cardCategory === category || button.textContent === 'All') {
            card.style.display = 'block';
            setTimeout(() => card.classList.add('visible'), 0);
          } else {
            card.style.display = 'none';
          }
        });
      });
    });
  }

  setupAddToCart() {
    const enrollButtons = document.querySelectorAll('.cenroll, .hcard-enroll, .pbtn-grad');
    enrollButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        if (button.classList.contains('pbtn-grad')) {
          this.openModal('register');
        } else {
          e.preventDefault();
          this.addToCart();
          this.showNotification('Course added to cart!', 'success');
        }
      });
    });
  }

  setupPaymentNavigation() {
    const paymentLinks = document.querySelectorAll('[data-page="payment"]');
    paymentLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        window.location.href = window.location.protocol === 'file:' ? 'pages/payment.html' : '/payment';
      });
    });
  }

  // ==================== LAZY LOADING ====================
  setupLazyLoading() {
    const lazyImages = document.querySelectorAll('img[data-src]');

    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target;
            img.src = img.dataset.src;
            img.classList.add('loaded');
            imageObserver.unobserve(img);
          }
        });
      });

      lazyImages.forEach(img => imageObserver.observe(img));
    } else {
      // Fallback for older browsers
      lazyImages.forEach(img => {
        img.src = img.dataset.src;
      });
    }
  }

  // ==================== SESSION MANAGEMENT ====================
  async checkUserSession() {
    try {
      // Check Supabase auth session
      const user = await window.supabaseConfig.getCurrentUser();
      if (user) {
        this.currentUser = user;
        await this.updateUIForLoggedInUser();
      }
    } catch (error) {
      console.error('Session check error:', error);
    }
  }

  async updateUIForLoggedInUser() {
    if (!this.currentUser) return;

    const profileSection = document.getElementById('profile-section');
    const signInBtn = document.getElementById('signin-btn');
    const ctaBtn = document.getElementById('cta-btn');
    const profileBtn = document.getElementById('profile-btn');

    // Show profile icon
    if (profileSection) {
      profileSection.style.display = 'flex';
      
      // Show profile initial
      if (profileBtn) {
        const name = this.currentUser.email?.split('@')[0] || 'User';
        profileBtn.textContent = name.charAt(0).toUpperCase();
      }
    }

    // Hide sign in, login wrapper, and get started buttons
    if (signInBtn) signInBtn.style.display = 'none';
    const loginBtn    = document.getElementById('login-btn');
    const loginWrapper = document.getElementById('login-wrapper');
    if (loginBtn)     loginBtn.style.display     = 'none';
    if (loginWrapper) loginWrapper.style.display = 'none';
    if (ctaBtn)       ctaBtn.style.display       = 'none';

    // Show admin link in dropdown if user is admin
    try {
      const adminCheck = await window.supabaseConfig.checkAdminAccess(this.currentUser.id);
      if (adminCheck && adminCheck.isAdmin) {
        const adminLink = document.getElementById('dd-admin-link');
        if (adminLink) adminLink.style.display = 'flex';
      }
    } catch(e) { /* not admin */ }
  }

  // ==================== SHOPPING CART ====================
  addToCart(course = null) {
    if (!course) {
      course = this.getSelectedCourseData();
    }

    this.cart.push({
      ...course,
      id: Date.now(),
      quantity: 1
    });

    localStorage.setItem('cart', JSON.stringify(this.cart));
  }

  removeFromCart(courseId) {
    this.cart = this.cart.filter(item => item.id !== courseId);
    localStorage.setItem('cart', JSON.stringify(this.cart));
  }

  getCart() {
    const cartData = localStorage.getItem('cart');
    return cartData ? JSON.parse(cartData) : [];
  }

  getSelectedCourseData() {
    return {
      name: 'Selected Course',
      price: 14999,
      duration: '48 hours'
    };
  }

  // ==================== EMI MANAGEMENT ====================
  createEMICalculator(courseId, price) {
    if (!this.emiCalculators[courseId]) {
      this.emiCalculators[courseId] = new EMICalculator();
    }
    return this.emiCalculators[courseId].calculate(price, 12, 12);
  }

  getEMIOptions(price) {
    const options = [
      { months: 3, rate: 0 },   // Zero cost
      { months: 6, rate: 0 },   // Zero cost
      { months: 12, rate: 0 },  // Zero cost
      { months: 24, rate: 12 }  // With interest
    ];

    return EMICalculator.compareOptions(price, options);
  }

  // ==================== NOTIFICATIONS ====================
  showNotification(message, type = 'info', duration = 3000) {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 1rem 1.5rem;
      background: var(--${type === 'success' ? 'v1' : 'v2'});
      color: white;
      border-radius: var(--r4);
      box-shadow: var(--shadow-btn);
      z-index: 9999;
      animation: slideInRight 0.3s ease;
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.animation = 'slideOutLeft 0.3s ease';
      setTimeout(() => notification.remove(), 300);
    }, duration);
  }

  // ==================== AUTHENTICATION ====================
  login(email, password) {
    // Mock authentication
    const user = {
      id: 1,
      name: email.split('@')[0],
      email: email,
      loginTime: new Date()
    };

    sessionStorage.setItem('userSession', JSON.stringify(user));
    this.currentUser = user;
    this.updateUIForLoggedInUser();
    this.closeModal();
    this.showNotification('Login successful!', 'success');

    return user;
  }

  logout() {
    sessionStorage.removeItem('userSession');
    this.currentUser = null;
    this.cart = [];
    localStorage.removeItem('cart');
    window.location.reload();
  }

  register(userData) {
    // Mock registration
    const user = {
      id: Math.random(),
      ...userData,
      registrationTime: new Date()
    };

    sessionStorage.setItem('userSession', JSON.stringify(user));
    this.currentUser = user;
    this.updateUIForLoggedInUser();
    this.closeModal();
    this.showNotification('Registration successful!', 'success');

    return user;
  }

  // ==================== UTILITIES ====================
  formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      minimumFractionDigits: 0
    }).format(amount);
  }

  formatDate(date) {
    return new Intl.DateTimeFormat('en-IN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    }).format(new Date(date));
  }

  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  throttle(func, limit) {
    let inThrottle;
    return function (...args) {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }

  // Analytics/Tracking
  trackEvent(eventName, eventData = {}) {
    console.log(`Event: ${eventName}`, eventData);
    // Send to analytics service
    if (window.gtag) {
      window.gtag('event', eventName, eventData);
    }
  }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.app = new SkillUpNowApp();
});

// Global functions for easy access
function openModal(type = 'login') {
  if (window.app) window.app.openModal(type);
}

function closeModal() {
  if (window.app) window.app.closeModal();
}

function switchModalTab(tab) {
  if (window.app) window.app.switchModalTab(tab);
}

function addToCart() {
  if (window.app) window.app.addToCart();
}

// Global admin login function
async function submitAdminLogin() {
  const emailEl = document.getElementById('admin-login-email');
  const passEl = document.getElementById('admin-login-password');
  const errEl = document.getElementById('admin-login-err');
  if (!emailEl || !passEl) return;
  const email = emailEl.value.trim();
  const pass = passEl.value;
  if (!email || !pass) {
    if (errEl) { errEl.textContent = 'Please enter email and password.'; errEl.style.display = 'block'; }
    return;
  }
  const btn = document.getElementById('admin-login-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'Signing in…'; }
  if (errEl) errEl.style.display = 'none';
  try {
    if (!window.supabaseConfig) throw new Error('Auth not ready');
    const result = await window.supabaseConfig.signIn(email, pass);
    if (!result.success) throw new Error(result.error || 'Login failed');
    const user = result.user || result.data?.user;
    if (!user) throw new Error('No user returned');
    const adminCheck = await window.supabaseConfig.checkAdminAccess(user.id);
    if (!adminCheck || !adminCheck.isAdmin) {
      await window.supabaseConfig.signOut();
      throw new Error('Access denied. Admin privileges required.');
    }
    window.location.href = window.location.protocol === 'file:'
      ? (window.location.pathname.includes('/pages/') ? '' : 'pages/') + 'admin-dashboard.html'
      : '/admin-dashboard';
  } catch (e) {
    if (errEl) { errEl.textContent = e.message || 'Login failed'; errEl.style.display = 'block'; }
    if (btn) { btn.disabled = false; btn.textContent = 'Admin Sign In'; }
  }
}

window.addEventListener('error', (event) => {
  console.error('Global error:', event);
  if (window.app) {
    window.app.showNotification('An error occurred. Please try again.', 'error');
  }
});

// Export for use
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SkillUpNowApp;
}
