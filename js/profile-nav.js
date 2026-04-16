/* ==========================================
   SITE COMPONENTS — Universal Header, Footer, Cursor & Auth Modal
   ========================================== */

class ProfileNavigationManager {
  constructor() {
    this.currentUser = null;
    const path = window.location.pathname.replace(/\\/g, '/');
    this.inPages     = path.includes('/pages/');
    this.rootPfx     = this.inPages ? '../' : '';
    this.pagesPfx    = this.inPages ? ''    : 'pages/';
    this.isAdminPage = path.includes('admin-dashboard') || path.includes('admin-login') || path.includes('admin-signup');
    this.isMentorPage = path.includes('mentor-dashboard');
    this._pendingOtpEmail = null;
    this._pendingOtpRole  = null;
    this._pendingOtpData  = null;
    this.init();
  }

  async init() {
    // Strip .html extension for clean URLs on all pages
    if (window.location.protocol !== 'file:') {
      const _p = window.location.pathname;
      if (_p.endsWith('.html')) {
        history.replaceState(null, '', _p.replace(/\.html$/, '').replace(/\/index$/, '/') + window.location.search + window.location.hash);
      }
    }
    this.injectFavicon();
    this.injectNeuralCursor(); // Always inject cursor — including admin and mentor pages
    if (this.isAdminPage || this.isMentorPage) return;
    this.injectThemeSwitcher(); // restores saved theme + injects CSS; setupBtn() is no-op (nav not built yet)
    this.rebuildNav();          // builds nav including #pn-theme-nav-btn
    this.injectThemeSwitcher(); // second call: CSS already injected (guard skips), theme already set, NOW wires btn
    this.replaceFooter();
    this.updateYearFields();
    this.setupMobileMenu();
    this.setupProfileDropdown();
    this.setupScrollNav();
    this.injectAuthModal();
    await this.checkUserSession();
    this.handleUrlAuth();
    this.setupKeyboardShortcuts();
  }

  /* ── Global keyboard shortcuts ── */
  setupKeyboardShortcuts() {
    const r = this.rootPfx, p = this.pagesPfx;
    document.addEventListener('keydown', (e) => {
      const tag = document.activeElement?.tagName?.toLowerCase();
      const inInput = tag === 'input' || tag === 'textarea' || tag === 'select' || document.activeElement?.isContentEditable;

      // Escape — close any open modal / overlay
      if (e.key === 'Escape') {
        const overlay = document.querySelector('.pn-overlay.open, .enroll-overlay.open, .ec-overlay.open, #enroll-overlay.open');
        if (overlay) { overlay.classList.remove('open'); document.body.style.overflow = ''; e.preventDefault(); return; }
        window._pnClose?.();
        return;
      }

      if (inInput) return; // don't fire nav shortcuts while typing

      // / — focus search bar (courses page)
      if (e.key === '/' && !e.altKey && !e.ctrlKey && !e.metaKey) {
        const search = document.getElementById('search-input') || document.querySelector('input[type="search"]');
        if (search) { search.focus(); e.preventDefault(); return; }
      }

      // Alt + key — page navigation
      if (e.altKey && !e.ctrlKey && !e.metaKey) {
        const nav = {
          h: r || '/',
          c: p + 'courses',
          f: p + 'forms',
          e: p + 'contact-enquiry',
          p: p + 'profile',
        };
        const dest = nav[e.key?.toLowerCase()];
        if (dest) { e.preventDefault(); window.location.href = dest; return; }

        // Alt+L — login/logout toggle
        if (e.key?.toLowerCase() === 'l') {
          e.preventDefault();
          if (this.currentUser) { this.logout?.(); } else { this.openLoginModal?.(); }
          return;
        }
      }
    });
  }

  /* ── Handle ?login=1 / ?signup=1 URL params ── */
  handleUrlAuth() {
    const p = new URLSearchParams(window.location.search);
    if (p.get('login') === '1')  { setTimeout(() => this.openLoginModal(), 300); }
    if (p.get('signup') === '1') { setTimeout(() => this.openRegister(), 300); }
  }

  /* ── Year placeholders ── */
  updateYearFields() {
    const year = new Date().getFullYear();
    document.querySelectorAll('.site-year').forEach(el => { el.textContent = year; });
  }

  /* ── Favicon ── */
  injectFavicon() {
    if (document.querySelector('link[rel~="icon"]')) return;
    const link = document.createElement('link');
    link.rel = 'icon';
    link.type = 'image/png';
    link.href = this.rootPfx + 'icon/Favicon.png';
    document.head.appendChild(link);
  }

  /* ── Neural cursor: disabled — hand cursor handled by CSS only ── */
  injectNeuralCursor() {
    // Cursor animations removed per design requirements.
    // Interactive elements get cursor:pointer via CSS.
  }

  /* ── Scroll: add .scrolled class to nav for effects ── */
  setupScrollNav() {
    const tick = () => {
      const nav = document.querySelector('nav');
      if (nav) nav.classList.toggle('scrolled', window.scrollY > 60);
    };
    window.addEventListener('scroll', tick, { passive: true });
    tick();
  }

  /* ── Theme Switcher — inline nav toggle near profile icon ── */
  injectThemeSwitcher() {
    // Restore saved theme first (runs on every page load)
    const saved = localStorage.getItem('pn-theme');
    const savedVariant = localStorage.getItem('pn-theme-variant');
    if (saved) document.documentElement.setAttribute('data-theme', saved);
    if (savedVariant && savedVariant !== 'purple') document.documentElement.setAttribute('data-theme-variant', savedVariant);
    else if (savedVariant === 'purple') document.documentElement.removeAttribute('data-theme-variant');

    // Inject nav button styles once
    if (!document.getElementById('pn-theme-nav-style')) {
      const s = document.createElement('style');
      s.id = 'pn-theme-nav-style';
      s.textContent = `
        .nav-theme-btn {
          width: 34px; height: 34px; border-radius: 50%;
          background: rgba(124,92,252,0.12);
          border: 1.5px solid rgba(124,92,252,0.25);
          display: flex; align-items: center; justify-content: center;
          cursor: pointer; font-size: .95rem;
          transition: background .2s, transform .25s cubic-bezier(.34,1.56,.64,1), box-shadow .2s;
          box-shadow: 0 2px 8px rgba(124,92,252,0.12);
          flex-shrink: 0;
        }
        .nav-theme-btn:hover {
          background: rgba(124,92,252,0.22);
          transform: scale(1.12) rotate(18deg);
          box-shadow: 0 4px 16px rgba(124,92,252,0.35);
        }
        :root[data-theme="light"] .nav-theme-btn {
          background: rgba(124,92,252,0.08);
          border-color: rgba(124,92,252,0.18);
        }
        /* Theme picker dropdown panel */
        #pn-theme-nav-panel {
          position: absolute; top: calc(100% + 10px); right: 0;
          background: color-mix(in srgb, var(--bg) 72%, rgba(10, 10, 18, 0.96));
          backdrop-filter: blur(20px) saturate(2);
          -webkit-backdrop-filter: blur(20px) saturate(2);
          border: 1px solid var(--border2);
          border-radius: 16px; padding: .5rem;
          display: flex; flex-direction: column; gap: .25rem;
          box-shadow: 0 16px 48px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.06);
          min-width: 190px; z-index: 9999;
          transform-origin: top right;
          transform: scale(0); opacity: 0;
          transition: transform .25s cubic-bezier(.34,1.56,.64,1), opacity .22s ease;
          pointer-events: none;
        }
        #pn-theme-nav-panel.open { transform: scale(1); opacity: 1; pointer-events: all; }
        :root[data-theme="light"] #pn-theme-nav-panel {
          background: rgba(255,255,255,0.97);
          border-color: rgba(124,92,252,0.15);
          box-shadow: 0 8px 32px rgba(124,92,252,0.18);
        }
        .pn-tn-option {
          display: flex; align-items: center; gap: .55rem;
          padding: .48rem .75rem; border-radius: 10px;
          cursor: pointer; font-size: .78rem; font-weight: 600;
          color: var(--txt2);
          border: 1px solid transparent; transition: all .16s;
          background: transparent; font-family: inherit; white-space: nowrap;
          width: 100%;
        }
        .pn-tn-option:hover {
          background: color-mix(in srgb, var(--v1) 14%, transparent);
          border-color: color-mix(in srgb, var(--v1) 36%, transparent);
        }
        .pn-tn-option.active {
          background: color-mix(in srgb, var(--v1) 18%, var(--panel));
          border-color: color-mix(in srgb, var(--v1) 50%, transparent);
          color: var(--txt);
        }
        .pn-tn-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
        .pn-tn-label { display: inline-flex; align-items: center; gap: .55rem; }
        .pn-tn-text { display: inline-flex; align-items: center; gap: .45rem; }
      `;
      document.head.appendChild(s);
    }

    // Wire up the nav button once it exists
    const setupBtn = () => {
      const btn = document.getElementById('pn-theme-nav-btn');
      if (!btn || btn._tsWired) return;
      btn._tsWired = true;

      // Update icon to reflect current theme
      const updateIcon = () => {
        const th = document.documentElement.getAttribute('data-theme') || 'dark';
        const vr = document.documentElement.getAttribute('data-theme-variant') || 'purple';
        const icons = { light: '☀️', ocean: '🌊', sunset: '🌅', emerald: '🌿', dark: '🌙' };
        btn.textContent = th === 'light' ? icons.light : (icons[vr] || icons.dark);
      };
      updateIcon();

      // Build dropdown panel
      const themes = [
        { id: 'dark',  icon: '🌙', label: 'Dark',    variant: 'purple'  },
        { id: 'light', icon: '☀️',  label: 'Light',   variant: 'purple'  },
        { id: 'dark',  icon: '🌊', label: 'Ocean',   variant: 'ocean'   },
        { id: 'dark',  icon: '🌅', label: 'Sunset',  variant: 'sunset'  },
        { id: 'dark',  icon: '🌿', label: 'Emerald', variant: 'emerald' },
      ];
      const dotColors = { purple: '#7c5cfc', ocean: '#0ea5e9', sunset: '#f59e0b', emerald: '#10b981' };
      const currentTh = document.documentElement.getAttribute('data-theme') || 'dark';
      const currentVr = document.documentElement.getAttribute('data-theme-variant') || 'purple';

      // Wrap the button in a relative container for the panel
      const wrap = document.createElement('div');
      wrap.style.cssText = 'position:relative;display:flex;align-items:center;';
      btn.parentNode.insertBefore(wrap, btn);
      wrap.appendChild(btn);

      const panel = document.createElement('div');
      panel.id = 'pn-theme-nav-panel';

      themes.forEach(t => {
        const opt = document.createElement('button');
        opt.className = 'pn-tn-option' + (t.id === currentTh && t.variant === currentVr ? ' active' : '');
        opt.type = 'button';
        opt.innerHTML = `<span class="pn-tn-label"><span class="pn-tn-dot" style="background:${dotColors[t.variant] || '#7c5cfc'};border:1.5px solid color-mix(in srgb, ${dotColors[t.variant] || '#7c5cfc'} 35%, rgba(255,255,255,.2));"></span><span class="pn-tn-text"><span>${t.icon}</span><span>${t.label}</span></span></span>`;
        opt.addEventListener('click', e => {
          e.stopPropagation();
          document.documentElement.setAttribute('data-theme', t.id);
          if (t.variant !== 'purple') document.documentElement.setAttribute('data-theme-variant', t.variant);
          else document.documentElement.removeAttribute('data-theme-variant');
          localStorage.setItem('pn-theme', t.id);
          localStorage.setItem('pn-theme-variant', t.variant);
          panel.querySelectorAll('.pn-tn-option').forEach(o => o.classList.remove('active'));
          opt.classList.add('active');
          panel.classList.remove('open');
          updateIcon();
        });
        panel.appendChild(opt);
      });
      wrap.appendChild(panel);

      btn.addEventListener('click', e => {
        e.stopPropagation();
        panel.classList.toggle('open');
      });
      document.addEventListener('click', () => panel.classList.remove('open'));
    };

    // The nav is built synchronously in rebuildNav() before injectThemeSwitcher() runs
    setupBtn();
  }

  /* ── Login Streak tracking (per-user, full date history) ── */
  _streakKey() {
    const uid = this.currentUser?.id;
    return uid ? 'pn_streak_v2_' + uid : null;
  }

  /* Returns sorted unique array of YYYY-MM-DD login dates (max 365) */
  _getLoginDates() {
    const key = this._streakKey();
    if (!key) return [];
    try {
      const stored = JSON.parse(localStorage.getItem(key) || '[]');
      return Array.isArray(stored) ? stored : [];
    } catch(_) { return []; }
  }

  /* Records today's login and returns current streak count */
  updateLoginStreak() {
    const key = this._streakKey();
    if (!key) return 0;
    const today = new Date().toISOString().slice(0, 10);
    let dates = this._getLoginDates();
    if (!dates.includes(today)) {
      dates.push(today);
      dates.sort();
      if (dates.length > 365) dates = dates.slice(-365); // keep last 365 days
      localStorage.setItem(key, JSON.stringify(dates));
    }
    return ProfileNavigationManager.calcCurrentStreak(dates);
  }

  getLoginStreak() {
    return ProfileNavigationManager.calcCurrentStreak(this._getLoginDates());
  }

  /* Static helpers used by both profile-nav.js and profile.html */
  static calcCurrentStreak(dates) {
    if (!dates.length) return 0;
    const today = new Date().toISOString().slice(0, 10);
    const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
    // Streak is alive if logged in today or yesterday (so closing browser overnight doesn't break it)
    const sorted = [...new Set(dates)].sort().reverse();
    if (sorted[0] !== today && sorted[0] !== yesterday) return 0;
    let streak = 0;
    let expected = sorted[0];
    for (const d of sorted) {
      if (d === expected) {
        streak++;
        const dt = new Date(expected);
        dt.setDate(dt.getDate() - 1);
        expected = dt.toISOString().slice(0, 10);
      } else {
        break;
      }
    }
    return streak;
  }

  static calcLongestStreak(dates) {
    if (!dates.length) return 0;
    const sorted = [...new Set(dates)].sort();
    let longest = 1, current = 1;
    for (let i = 1; i < sorted.length; i++) {
      const prev = new Date(sorted[i - 1]);
      const curr = new Date(sorted[i]);
      const diff = (curr - prev) / 86400000;
      if (diff === 1) { current++; longest = Math.max(longest, current); }
      else { current = 1; }
    }
    return longest;
  }

  showStreakBadge() {
    const streak = this.updateLoginStreak();
    const profileSection = document.getElementById('profile-section');
    if (!profileSection || streak < 1) return;
    // Remove existing badge
    profileSection.querySelector('.streak-badge')?.remove();
    if (streak > 0) {
      const badge = document.createElement('div');
      badge.className = 'streak-badge';
      badge.title = streak + ' day streak! 🔥';
      badge.innerHTML = streak > 99 ? '99+' : (streak >= 2 ? '🔥' + streak : '🔥');
      profileSection.style.position = 'relative';
      profileSection.appendChild(badge);
    }
  }

  /* ── Build nav HTML ── */
  buildNavHTML() {
    const r = this.rootPfx;
    const p = this.pagesPfx;
    const path = window.location.pathname.replace(/\\/g, '/');
    const isHome    = path.endsWith('/') || path.endsWith('index.html') || path.endsWith('index');
    const isCourses = path.includes('courses');
    const isEnquiry = path.includes('contact-enquiry');
    const isVideos  = path.includes('recording-videos');
    const isForms   = path.includes('forms');

    return `
      <a href="${r || '/'}" class="nav-logo" aria-label="SkillUpNow Home" style="padding:0;background:none;gap:0;">
        <img src="${r}icon/Logo.png" alt="SkillUpNow" style="height:44px;width:auto;object-fit:contain;display:block;" onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
        <span style="display:none;align-items:center;gap:.5rem;font-size:1.1rem;font-weight:800;">SkillUpNow</span>
      </a>

      <ul class="nav-links" id="nav-links-list" role="navigation" aria-label="Main navigation">
        <li><a href="${r || '/'}"                        class="nav-link-item ${isHome    ? 'active' : ''}">Home</a></li>
        <li><a href="${p}courses"                        class="nav-link-item ${isCourses ? 'active' : ''}">Courses</a></li>
        <li><a href="${p}recording-videos"               class="nav-link-item ${isVideos  ? 'active' : ''}">Videos</a></li>
        <li><a href="${p}forms" class="nav-link-item ${isForms ? 'active' : ''}">Forms</a></li>
        <li><a href="${p}contact-enquiry"                class="nav-link-item ${isEnquiry ? 'active' : ''}">Enquiry</a></li>
      </ul>

      <div class="nav-actions" id="nav-actions">

        <!-- Theme toggle (near profile) -->
        <button id="pn-theme-nav-btn" class="nav-theme-btn" aria-label="Toggle theme" title="Switch theme">🌙</button>

        <!-- Profile: shown after login -->
        <div id="profile-section" style="display:none;align-items:center;position:relative;">
          <button id="profile-btn" class="profile-icon-btn" aria-label="My profile" aria-haspopup="true" aria-expanded="false">U</button>
          <div id="profile-dropdown" class="profile-dropdown" role="menu">
            <div class="pd-header" id="pd-user-info">
              <div class="pd-avatar-sm" id="pd-avatar-sm">U</div>
              <div>
                <div class="pd-user-name" id="pd-name">User</div>
                <div class="pd-user-email" id="pd-email"></div>
              </div>
            </div>
            <div class="pd-divider"></div>
            <a href="${p}profile" class="pd-item" role="menuitem">
              <span class="pd-icon">🎓</span>
              <div><div class="pd-title">My Dashboard</div><div class="pd-sub">Learning path & progress</div></div>
            </a>
            <a href="${p}profile?tab=payments" class="pd-item" role="menuitem">
              <span class="pd-icon">💳</span>
              <div><div class="pd-title">Payments & EMI</div><div class="pd-sub">Invoices & installments</div></div>
            </a>
            <a id="dd-mentor-link" href="${p}mentor-dashboard" class="pd-item" role="menuitem" style="display:none;">
              <span class="pd-icon">📋</span>
              <div><div class="pd-title">Mentor Portal</div><div class="pd-sub">Batches & schedules</div></div>
            </a>
            <a id="dd-admin-link" href="${p}admin-dashboard" class="pd-item" role="menuitem" style="display:none;">
              <span class="pd-icon">⚙️</span>
              <div><div class="pd-title">Admin Panel</div><div class="pd-sub">Manage platform</div></div>
            </a>
            <div class="pd-divider"></div>
            <button onclick="window.profileNav && window.profileNav.logout()" class="pd-item pd-logout" role="menuitem">
              <span class="pd-icon">🚪</span>
              <div><div class="pd-title" style="color:#ff6b6b;">Sign Out</div><div class="pd-sub">See you soon!</div></div>
            </button>
          </div>
        </div>

        <!-- Auth buttons: shown when logged out (visible by default, hidden on login) -->
        <div id="login-wrapper" style="display:flex;align-items:center;gap:.6rem;">
          <button id="login-btn" class="nav-signin" onclick="window.profileNav && window.profileNav.openLoginModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/></svg>
            Login
          </button>
          <button id="cta-btn" class="nav-cta nav-signup-btn" onclick="window.profileNav && window.profileNav.openRegister()">
            Sign Up
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
          </button>
        </div>

        <!-- Mobile hamburger -->
        <button class="mobile-menu-toggle" id="mobile-toggle" aria-label="Open menu" aria-expanded="false">
          <span></span><span></span><span></span>
        </button>
      </div>
    `;
  }

  /* ── Build footer HTML ── */
  buildFooterHTML() {
    const r = this.rootPfx;
    const p = this.pagesPfx;
    return `
      <style>
        /* ── Single-line footer ── */
        .footer-inner {
          display: flex; align-items: flex-start; flex-wrap: nowrap;
          gap: 0 2rem;
          max-width: 1400px; margin: 0 auto;
          padding: 2rem 5vw 1.5rem;
        }
        .pn-f-logo  { flex: 0 0 auto; display:flex; align-items:flex-start; padding-top:.1rem; margin-right:.25rem; }
        .pn-f-contact { flex: 1.4; min-width: 0; display:flex; flex-direction:column; gap:.3rem; }
        .pn-f-contact-row { display:flex; flex-wrap:wrap; gap:.25rem .9rem; align-items:center; margin-top:.15rem; }
        .pn-f-platform { flex: 1; min-width: 0; }
        .pn-f-company  { flex: 1; min-width: 0; }
        .pn-footer-phone { color:#4ade80; }
        /* Icon-only — no background */
        .pn-f-3d-icon {
          display:inline-flex; align-items:center; justify-content:center;
          flex-shrink:0; transition: opacity .16s;
        }
        .pn-f-3d-link:hover .pn-f-3d-icon { opacity:.65; }
        .pn-f-phone-icon { color:#16a34a; }
        .pn-f-email-icon { color:#4f46e5; }
        .pn-f-loc-icon   { color:#ea580c; }
        .pn-f-3d-link { color:var(--txt3); text-decoration:none; transition:color .18s; }
        .pn-f-3d-link:hover { color:var(--txt); }
        @media(max-width:900px){
          .footer-inner { flex-wrap:wrap; gap:1.5rem 2rem; }
          .pn-f-logo { flex: 0 0 auto; }
          .pn-f-contact { flex: 1 1 200px; }
          .pn-f-platform { flex: 1 1 130px; }
          .pn-f-company  { flex: 1 1 130px; }
        }
        @media(max-width:480px){
          .footer-inner { flex-direction:column; gap:1.25rem; }
        }
      </style>

      <div class="footer-inner">
        <!-- Logo -->
        <div class="pn-f-logo">
          <a href="${r || '/'}" aria-label="SkillUpNow Home" style="display:block;">
            <img src="${r}icon/Logo.png" alt="SkillUpNow" style="height:48px;width:auto;object-fit:contain;" onerror="this.alt='SkillUpNow';this.style.display='none';">
          </a>
        </div>

        <!-- Contact -->
        <div class="pn-f-contact">
          <h5 class="footer-col-title" style="margin-bottom:.4rem;">Contact</h5>
          <div class="pn-f-contact-row" style="margin-bottom:.35rem;">
            <a href="mailto:skillupnowoff@gmail.com" class="footer-contact-link pn-f-3d-link" style="font-size:.79rem;white-space:nowrap;display:flex;align-items:center;gap:.45rem;">
              <span class="pn-f-3d-icon pn-f-email-icon" aria-hidden="true">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m2 7 10 7 10-7"/></svg>
              </span>
              skillupnowoff@gmail.com
            </a>
          </div>
          <div class="pn-f-contact-row" style="flex-direction:column;gap:.25rem;align-items:flex-start;">
            <a href="tel:+916383633054" class="footer-contact-link pn-f-3d-link" style="font-size:.79rem;white-space:nowrap;display:flex;align-items:center;gap:.45rem;">
              <span class="pn-f-3d-icon pn-f-phone-icon" aria-hidden="true">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2c.27-.27.67-.36 1-.24 1.1.36 2.3.56 3.56.56.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.29 21 3 13.71 3 4.5c0-.55.45-1 1-1H7.5c.55 0 1 .45 1 1 0 1.25.2 2.45.56 3.56.12.35.03.74-.22 1L6.6 10.8z"/></svg>
              </span>
              +91 63836 33054
            </a>
            <a href="tel:+916381721061" class="footer-contact-link pn-f-3d-link" style="font-size:.79rem;white-space:nowrap;display:flex;align-items:center;gap:.45rem;">
              <span class="pn-f-3d-icon pn-f-phone-icon" aria-hidden="true">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2c.27-.27.67-.36 1-.24 1.1.36 2.3.56 3.56.56.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.29 21 3 13.71 3 4.5c0-.55.45-1 1-1H7.5c.55 0 1 .45 1 1 0 1.25.2 2.45.56 3.56.12.35.03.74-.22 1L6.6 10.8z"/></svg>
              </span>
              +91 63817 21061
            </a>
            <a href="tel:+918754470742" class="footer-contact-link pn-f-3d-link" style="font-size:.79rem;white-space:nowrap;display:flex;align-items:center;gap:.45rem;">
              <span class="pn-f-3d-icon pn-f-phone-icon" aria-hidden="true">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2c.27-.27.67-.36 1-.24 1.1.36 2.3.56 3.56.56.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.29 21 3 13.71 3 4.5c0-.55.45-1 1-1H7.5c.55 0 1 .45 1 1 0 1.25.2 2.45.56 3.56.12.35.03.74-.22 1L6.6 10.8z"/></svg>
              </span>
              +91 87544 70742
            </a>
            <span class="footer-contact-link pn-f-3d-link" style="font-size:.79rem;display:flex;align-items:center;gap:.45rem;cursor:default;">
              <span class="pn-f-3d-icon pn-f-loc-icon" aria-hidden="true">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a7 7 0 0 0-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 0 0-7-7z"/><circle cx="12" cy="9" r="2"/></svg>
              </span>
              Chennai, Tamil Nadu, India
            </span>
          </div>
        </div>

        <!-- Platform links -->
        <div class="pn-f-platform">
          <h5 class="footer-col-title" style="margin-bottom:.3rem;">Platform</h5>
          <ul class="footer-col-links">
            <li><a href="${p}courses"         class="footer-link">All Courses</a></li>
            <li><a href="${p}recording-videos" class="footer-link">Recorded Sessions</a></li>
            <li><a href="${p}emi-application"  class="footer-link">EMI Options</a></li>
            <li><a href="${p}pamphlet"          class="footer-link">Brochure</a></li>
          </ul>
        </div>

        <!-- Company links -->
        <div class="pn-f-company">
          <h5 class="footer-col-title" style="margin-bottom:.3rem;">Company</h5>
          <ul class="footer-col-links">
            <li><a href="${r || '/'}#about-us"       class="footer-link">About Us</a></li>
            <li><a href="${p}contact-enquiry"        class="footer-link">Contact</a></li>
            <li><a href="#"                         class="footer-link">Privacy Policy</a></li>
            <li><a href="#"                         class="footer-link">Terms of Service</a></li>
          </ul>
        </div>
      </div>

      <div class="footer-bottom">
        <p class="footer-copy">© 2026, SkillUpNow, Chennai. All rights reserved.</p>
        <div class="footer-socials">
          <a href="https://www.instagram.com/skillupnow" class="footer-social-icon" aria-label="Instagram" title="Instagram" target="_blank" rel="noopener">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="20" rx="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/></svg>
          </a>
          <a href="https://www.linkedin.com/company/skillupnow" class="footer-social-icon" aria-label="LinkedIn" title="LinkedIn" target="_blank" rel="noopener">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/></svg>
          </a>
        </div>
      </div>
    `;
  }

  /* ── Rebuild nav element ── */
  rebuildNav() {
    const nav = document.querySelector('nav:not([data-skip-component])');
    if (!nav) return;
    nav.innerHTML = this.buildNavHTML();
  }

  /* ── Replace footer ── */
  replaceFooter() {
    const footers = document.querySelectorAll('footer:not([data-skip-component])');
    if (!footers.length) return;
    footers.forEach((footer, idx) => {
      if (idx < footers.length - 1) { footer.remove(); return; }
      footer.className = 'site-footer';
      footer.removeAttribute('style');
      footer.innerHTML = this.buildFooterHTML();
    });
    this.loadFooterReviews();
  }

  /* ── Load 3 recent approved reviews into footer ── */
  async loadFooterReviews() {
    const container = document.getElementById('footer-review-list');
    if (!container) return;
    try {
      const client = window.supabaseConfig?.client;
      if (!client) { container.innerHTML = ''; return; }
      const { data: reviews } = await client
        .from('reviews')
        .select('reviewer_name, rating, comment')
        .eq('is_approved', true)
        .order('created_at', { ascending: false })
        .limit(3);
      if (!reviews || !reviews.length) {
        container.innerHTML = '<div style="font-size:.78rem;color:var(--txt4);">No reviews yet.</div>';
        return;
      }
      container.innerHTML = reviews.map(r => `
        <div style="background:var(--panel2);border:1px solid var(--border);border-radius:10px;padding:.75rem .9rem;">
          <div style="display:flex;align-items:center;gap:.4rem;margin-bottom:.35rem;">
            <span style="font-size:.75rem;color:#fbbf24;">${'★'.repeat(Math.min(5,Math.max(1,r.rating||5)))}${'☆'.repeat(5-Math.min(5,Math.max(1,r.rating||5)))}</span>
            <span style="font-size:.72rem;font-weight:700;color:var(--txt2);">${(r.reviewer_name||'Student').split(' ')[0]}</span>
          </div>
          <p style="font-size:.78rem;color:var(--txt3);line-height:1.5;margin:0;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;">${r.comment||''}</p>
        </div>`).join('');
    } catch (_) {
      container.innerHTML = '<div style="font-size:.78rem;color:var(--txt4);">Reviews unavailable.</div>';
    }
  }

  /* ── Mobile hamburger ── */
  setupMobileMenu() {
    const toggle   = document.getElementById('mobile-toggle');
    const navLinks = document.getElementById('nav-links-list');
    const nav      = document.querySelector('nav');
    if (!toggle || !navLinks) return;

    toggle.addEventListener('click', e => {
      e.stopPropagation();
      const isOpen = navLinks.classList.toggle('mobile-open');
      toggle.classList.toggle('open', isOpen);
      toggle.setAttribute('aria-expanded', isOpen);
      toggle.setAttribute('aria-label', isOpen ? 'Close menu' : 'Open menu');
    });

    document.addEventListener('click', e => {
      if (nav && !nav.contains(e.target)) {
        navLinks.classList.remove('mobile-open');
        toggle.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });

    navLinks.querySelectorAll('a').forEach(a => {
      a.addEventListener('click', () => {
        navLinks.classList.remove('mobile-open');
        toggle.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  /* ── Profile dropdown ── */
  setupProfileDropdown() {
    document.addEventListener('click', e => {
      const btn  = document.getElementById('profile-btn');
      const dd   = document.getElementById('profile-dropdown');
      if (!btn || !dd) return;
      if (btn.contains(e.target)) {
        const open = dd.classList.toggle('active');
        btn.setAttribute('aria-expanded', open);
      } else if (!dd.contains(e.target)) {
        dd.classList.remove('active');
        btn.setAttribute('aria-expanded', 'false');
      }
    });
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') {
        document.getElementById('profile-dropdown')?.classList.remove('active');
        document.getElementById('profile-btn')?.setAttribute('aria-expanded', 'false');
      }
    });
  }

  /* ======================================================
     NEW AUTH MODAL — Completely redesigned
     ====================================================== */
  injectAuthModal() {
    if (document.getElementById('pn-auth-modal')) return;

    // Email verification is handled by Supabase's built-in email system.
    // No EmailJS or custom OTP needed.

    /* ── CSS ── */
    const pnEmailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const pnPhoneRe = /^[6-9]\d{9}$/;
    const pnPasswordRe = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
    const pnNormalizePhone = value => (value || '').replace(/\D/g, '').slice(0, 10);

    const style = document.createElement('style');
    style.id = 'pn-auth-modal-style';
    style.textContent = `
      /* ── Overlay — deep blurred glass backdrop ── */
      #pn-auth-modal {
        position: fixed; inset: 0; z-index: 99999;
        background: rgba(8, 4, 28, 0.62);
        backdrop-filter: blur(22px) saturate(1.8);
        -webkit-backdrop-filter: blur(22px) saturate(1.8);
        display: flex; align-items: center; justify-content: center;
        padding: 1rem;
        opacity: 0; visibility: hidden; pointer-events: none;
        transition: opacity .28s ease, visibility .28s ease;
      }
      #pn-auth-modal.pn-open {
        opacity: 1; visibility: visible; pointer-events: all;
      }

      /* ── Box — liquid glossy card ── */
      .pn-box {
        width: 100%; max-width: 680px;
        max-height: 94vh; overflow-y: auto; overflow-x: hidden;
        background: rgba(255,255,255,0.92);
        backdrop-filter: blur(28px) saturate(2);
        -webkit-backdrop-filter: blur(28px) saturate(2);
        border: 1.5px solid rgba(255,255,255,0.65);
        border-radius: 28px;
        padding: 2.5rem 2.2rem 2rem;
        position: relative;
        box-shadow:
          0 32px 80px rgba(60,20,160,.18),
          0 8px 32px rgba(124,92,252,.12),
          inset 0 1px 0 rgba(255,255,255,0.95),
          inset 0 -1px 0 rgba(124,92,252,0.06);
        transform: scale(.93) translateY(24px);
        transition: transform .34s cubic-bezier(.22,1,.36,1);
      }
      /* Liquid shimmer top line */
      .pn-box::before {
        content: '';
        position: absolute; top: 0; left: 0; right: 0; height: 3px;
        background: linear-gradient(90deg, #7c5cfc, #3d6bff, #a78bfa, #7c5cfc);
        background-size: 200% 100%;
        border-radius: 28px 28px 0 0;
        animation: pn-shimmer 3s linear infinite;
      }
      @keyframes pn-shimmer { 0% { background-position: 0% 0; } 100% { background-position: 200% 0; } }
      /* Glossy glare highlight */
      .pn-box::after {
        content: '';
        position: absolute; top: 3px; left: 10%; right: 10%; height: 50%;
        background: linear-gradient(180deg, rgba(255,255,255,0.28) 0%, rgba(255,255,255,0) 100%);
        border-radius: 28px 28px 60% 60%;
        pointer-events: none;
      }
      #pn-auth-modal.pn-open .pn-box { transform: scale(1) translateY(0); }

      /* Dark theme glass box */
      :root[data-theme="dark"] .pn-box,
      html[data-theme="dark"] .pn-box {
        background: rgba(16, 10, 42, 0.88);
        border-color: rgba(124,92,252,0.28);
        box-shadow:
          0 32px 80px rgba(0,0,0,0.6),
          0 8px 32px rgba(124,92,252,0.22),
          inset 0 1px 0 rgba(255,255,255,0.08),
          inset 0 -1px 0 rgba(124,92,252,0.06);
      }
      :root[data-theme="dark"] .pn-title,
      html[data-theme="dark"] .pn-title { color: #f0eeff; }
      :root[data-theme="dark"] .pn-sub,
      html[data-theme="dark"] .pn-sub { color: rgba(200,191,255,0.5); }
      :root[data-theme="dark"] .pn-field label,
      html[data-theme="dark"] .pn-field label { color: rgba(200,191,255,0.5); }
      :root[data-theme="dark"] .pn-field input,
      :root[data-theme="dark"] .pn-field select,
      html[data-theme="dark"] .pn-field input,
      html[data-theme="dark"] .pn-field select {
        background: rgba(255,255,255,0.06);
        border-color: rgba(124,92,252,0.22);
        color: #f0eeff;
      }
      :root[data-theme="dark"] .pn-field input::placeholder,
      html[data-theme="dark"] .pn-field input::placeholder { color: rgba(200,191,255,0.28); }
      :root[data-theme="dark"] .pn-field input:focus,
      :root[data-theme="dark"] .pn-field select:focus,
      html[data-theme="dark"] .pn-field input:focus,
      html[data-theme="dark"] .pn-field select:focus {
        border-color: rgba(155,143,255,0.7);
        background: rgba(124,92,252,0.1);
        box-shadow: 0 0 0 3px rgba(124,92,252,0.18);
      }
      :root[data-theme="dark"] .pn-role-card,
      html[data-theme="dark"] .pn-role-card {
        background: rgba(255,255,255,0.04);
        border-color: rgba(124,92,252,0.2);
      }
      :root[data-theme="dark"] .pn-role-name,
      html[data-theme="dark"] .pn-role-name { color: #f0eeff; }
      :root[data-theme="dark"] .pn-role-desc,
      html[data-theme="dark"] .pn-role-desc { color: rgba(200,191,255,0.45); }
      :root[data-theme="dark"] .pn-close,
      html[data-theme="dark"] .pn-close {
        background: rgba(124,92,252,0.15);
        border-color: rgba(124,92,252,0.3);
        color: #b5adff;
      }
      :root[data-theme="dark"] .pn-brand-name,
      html[data-theme="dark"] .pn-brand-name {
        background: linear-gradient(135deg,#c4b5fd 0%,#93c5fd 100%);
        -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
      }
      :root[data-theme="dark"] .pn-switch,
      html[data-theme="dark"] .pn-switch { color: rgba(200,191,255,0.5); }
      :root[data-theme="dark"] .pn-otp-input,
      html[data-theme="dark"] .pn-otp-input {
        background: rgba(255,255,255,0.05);
        border-color: rgba(124,92,252,0.25);
        color: #f0eeff;
      }
      :root[data-theme="dark"] .pn-terms,
      html[data-theme="dark"] .pn-terms { color: rgba(200,191,255,0.5); }
      :root[data-theme="dark"] .pn-info-note,
      html[data-theme="dark"] .pn-info-note {
        background: rgba(255,255,255,0.04);
        border-color: rgba(124,92,252,0.2);
        color: rgba(200,191,255,0.6);
      }
      :root[data-theme="dark"] .pn-err,
      html[data-theme="dark"] .pn-err {
        background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #fca5a5;
      }
      :root[data-theme="dark"] .pn-ok,
      html[data-theme="dark"] .pn-ok {
        background: rgba(34,197,94,0.1); border-color: rgba(34,197,94,0.3); color: #86efac;
      }
      :root[data-theme="dark"] .pn-forgot a,
      :root[data-theme="dark"] .pn-switch a,
      html[data-theme="dark"] .pn-forgot a,
      html[data-theme="dark"] .pn-switch a { color: #a78bfa; }
      :root[data-theme="dark"] .pn-success h3,
      html[data-theme="dark"] .pn-success h3 { color: #f0eeff; }
      :root[data-theme="dark"] .pn-success p,
      html[data-theme="dark"] .pn-success p { color: rgba(200,191,255,0.55); }

      /* ── Scrollbar ── */
      .pn-box::-webkit-scrollbar { width: 3px; }
      .pn-box::-webkit-scrollbar-thumb { background: rgba(124,92,252,.2); border-radius: 3px; }

      /* ── Close ── */
      .pn-close {
        position: absolute; top: 1.1rem; right: 1.1rem;
        width: 32px; height: 32px; border-radius: 50%;
        border: 1.5px solid #e5e0ff;
        background: #f5f3ff;
        color: #9b7dff;
        font-size: .8rem; font-weight: 700;
        display: flex; align-items: center; justify-content: center;
        cursor: pointer; transition: all .2s; font-family: inherit; line-height: 1;
      }
      .pn-close:hover { background: #ede9ff; border-color: #c4b5fd; color: #7c5cfc; transform: scale(1.12) rotate(90deg); }

      /* ── Brand header ── */
      .pn-brand { display: flex; align-items: center; gap: .6rem; margin-bottom: 1.6rem; }
      .pn-brand-logo {
        width: 38px; height: 38px; border-radius: 11px;
        background: linear-gradient(135deg,#7c5cfc,#3d6bff);
        display: flex; align-items: center; justify-content: center;
        box-shadow: 0 4px 16px rgba(124,92,252,.35); flex-shrink: 0;
      }
      .pn-brand-name {
        font-size: .95rem; font-weight: 800;
        background: linear-gradient(135deg,#4c1d95 0%,#1e40af 100%);
        -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
      }
      .pn-badge {
        margin-left: auto; background: rgba(74,222,128,.1);
        border: 1px solid rgba(34,197,94,.3); border-radius: 999px;
        padding: .2rem .6rem; font-size: .65rem; font-weight: 700;
        color: #16a34a; letter-spacing: .04em;
      }

      /* ── Titles ── */
      .pn-title {
        font-size: 1.7rem; font-weight: 900; letter-spacing: -.03em;
        color: #12103a; line-height: 1.15; margin-bottom: .35rem;
      }
      .pn-title span {
        background: linear-gradient(135deg,#7c5cfc,#3d6bff);
        -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
      }
      .pn-sub { font-size: .83rem; color: #6b7280; margin-bottom: 1.8rem; line-height: 1.55; }

      /* ── Role cards ── */
      .pn-role-cards { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; margin-bottom: 1.4rem; }
      .pn-role-card {
        background: #faf9ff;
        border: 1.5px solid #e5e0ff;
        border-radius: 16px; padding: 1.4rem 1rem;
        text-align: center; cursor: pointer;
        transition: all .22s cubic-bezier(.4,0,.2,1);
        outline: none; position: relative; overflow: hidden;
      }
      .pn-role-card::after {
        content: ''; position: absolute; inset: 0;
        background: linear-gradient(135deg,rgba(124,92,252,.07),transparent);
        opacity: 0; transition: opacity .22s;
      }
      .pn-role-card:hover, .pn-role-card:focus-visible {
        border-color: #7c5cfc;
        transform: translateY(-3px);
        box-shadow: 0 8px 28px rgba(124,92,252,.15);
      }
      .pn-role-card:hover::after { opacity: 1; }
      .pn-role-icon { font-size: 2.1rem; margin-bottom: .5rem; display: block; }
      .pn-role-name { font-size: .88rem; font-weight: 800; color: #12103a; margin-bottom: .2rem; }
      .pn-role-desc { font-size: .7rem; color: #9ca3af; line-height: 1.4; }

      /* ── Divider ── */
      .pn-divider-text {
        display: flex; align-items: center; gap: .7rem;
        font-size: .7rem; color: #d1d5db; font-weight: 600;
        letter-spacing: .06em; margin: .8rem 0 1rem;
      }
      .pn-divider-text::before, .pn-divider-text::after {
        content: ''; flex: 1; height: 1px; background: #f0f0f8;
      }

      /* ── Back btn — liquid glass style ── */
      .pn-back {
        display: inline-flex; align-items: center; gap: .45rem;
        padding: .42rem 1rem .42rem .7rem;
        background: rgba(124,92,252,0.08);
        -webkit-backdrop-filter: blur(10px); backdrop-filter: blur(10px);
        border: 1.5px solid rgba(124,92,252,0.2);
        border-radius: 999px;
        color: #9b8fff; font-size: .8rem; font-weight: 700;
        cursor: pointer; font-family: inherit;
        margin-bottom: 1.4rem;
        transition: background .2s, border-color .2s, transform .22s cubic-bezier(.34,1.56,.64,1), color .2s;
        letter-spacing: .01em;
      }
      .pn-back:hover {
        background: rgba(124,92,252,0.18); border-color: rgba(124,92,252,.5);
        color: #c4b5fd; transform: translateX(-3px) scale(1.04);
      }
      :root[data-theme="dark"] .pn-back,
      html[data-theme="dark"] .pn-back { color: rgba(200,191,255,0.6); border-color: rgba(124,92,252,.25); }

      /* ── Field ── */
      .pn-field { margin-bottom: .85rem; }
      .pn-field label {
        display: block; font-size: .72rem; font-weight: 700;
        color: #6b7280; text-transform: uppercase;
        letter-spacing: .07em; margin-bottom: .38rem;
      }
      /* Red asterisk for required fields */
      .pn-field label .req, .pn-field label:has(+ input[required]) .req { color: #ef4444; font-weight: 900; }
      .pn-req { color: #ef4444 !important; font-weight: 900 !important; margin-left: 1px; }
      /* Input validation states */
      .pn-field input.valid { border-color: #22c55e !important; }
      .pn-field input.invalid { border-color: #ef4444 !important; }
      .pn-field .pn-field-hint {
        font-size: .66rem; margin-top: .2rem; padding: .18rem .45rem;
        border-radius: 6px; display: none;
      }
      .pn-field .pn-field-hint.show { display: block; }
      .pn-field .pn-field-hint.err { color: #ef4444; background: rgba(239,68,68,.08); }
      .pn-field .pn-field-hint.ok { color: #22c55e; background: rgba(34,197,94,.08); }
      .pn-field-row { display: grid; grid-template-columns: 1fr 1fr; gap: .65rem; }
      .pn-field input, .pn-field select {
        width: 100%; padding: .8rem 1rem;
        background: #f9f8ff;
        border: 1.5px solid #e5e0ff;
        border-radius: 12px; color: #12103a;
        font-size: .87rem; font-family: inherit;
        transition: border-color .2s, box-shadow .2s; outline: none;
      }
      .pn-field input:focus, .pn-field select:focus {
        border-color: #7c5cfc;
        background: #fff;
        box-shadow: 0 0 0 3px rgba(124,92,252,.1);
      }
      .pn-field input::placeholder { color: #c4b5fd; }
      .pn-field select option { background: #fff; color: #12103a; }
      .pn-field .pn-pw-wrap { position: relative; }
      .pn-field .pn-pw-wrap input { padding-right: 2.8rem; }
      .pn-pw-toggle {
        position: absolute; right: .75rem; top: 50%; transform: translateY(-50%);
        background: none; border: none; color: #c4b5fd;
        cursor: pointer; padding: .25rem; line-height: 0; transition: color .2s, background .2s;
        display: flex; align-items: center; justify-content: center;
        border-radius: 6px; width: 28px; height: 28px;
      }
      .pn-pw-toggle:hover { color: #7c5cfc; background: rgba(124,92,252,.1); }

      /* ── Strength bar ── */
      .pn-strength { height: 3px; border-radius: 3px; margin-top: .4rem; transition: all .3s; background: #f0eeff; }
      .pn-strength-label { font-size: .65rem; color: #9ca3af; margin-top: .25rem; }

      /* ── Password hints ── */
      .pn-pw-hints { display: flex; flex-wrap: wrap; gap: .35rem; margin-top: .5rem; }
      .pn-pw-hint {
        font-size: .65rem; padding: .18rem .5rem; border-radius: 999px;
        background: #f5f3ff; border: 1px solid #e5e0ff;
        color: #9ca3af; transition: all .2s;
      }
      .pn-pw-hint.ok { background: rgba(74,222,128,.1); border-color: rgba(34,197,94,.3); color: #16a34a; }

      /* ── Terms — green rounded button style ── */
      .pn-terms {
        display: flex; align-items: center; gap: .75rem; margin-bottom: .9rem;
        font-size: .75rem; color: #6b7280; line-height: 1.5; cursor: pointer;
      }
      .pn-terms input[type=checkbox] { display:none; }
      .pn-terms-check {
        flex-shrink: 0; width: 28px; height: 28px;
        border-radius: 999px; border: 2px solid #d1d5db;
        background: #fff; display: flex; align-items: center; justify-content: center;
        transition: all .22s cubic-bezier(.34,1.56,.64,1); font-size: 1rem; color: transparent;
        box-shadow: 0 1px 4px rgba(0,0,0,.06);
      }
      .pn-terms input[type=checkbox]:checked + .pn-terms-check {
        background: #22c55e; border-color: #16a34a; color: #fff;
        box-shadow: 0 4px 12px rgba(34,197,94,.35);
      }
      .pn-terms a { color: #7c5cfc; text-decoration: none; }
      .pn-terms a:hover { color: #5b3fd4; text-decoration: underline; }

      /* ── Submit btn (animated gradient, light) ── */
      .pn-btn {
        width: 100%; padding: .9rem;
        background: linear-gradient(135deg, #7c5cfc 0%, #3d6bff 50%, #7c5cfc 100%);
        background-size: 200% 100%;
        color: #fff; border: none; border-radius: 50px;
        font-size: .92rem; font-weight: 700; cursor: pointer;
        transition: background-position .4s ease, filter .2s, transform .2s, opacity .2s, box-shadow .2s;
        box-shadow: 0 6px 24px rgba(124,92,252,.35), 0 0 0 0 rgba(124,92,252,.25);
        font-family: inherit; letter-spacing: .01em; position: relative; overflow: hidden;
        animation: pn-btn-pulse 2.6s ease-in-out infinite;
      }
      @keyframes pn-btn-pulse {
        0%,100% { box-shadow: 0 6px 24px rgba(124,92,252,.35), 0 0 0 0 rgba(124,92,252,.25); }
        50%      { box-shadow: 0 8px 28px rgba(124,92,252,.5), 0 0 0 6px rgba(124,92,252,0); }
      }
      .pn-btn::after {
        content: ''; position: absolute; inset: 0;
        background: linear-gradient(105deg,transparent 30%,rgba(255,255,255,.18) 50%,transparent 70%);
        transform: translateX(-120%); transition: transform .5s ease;
      }
      .pn-btn:hover::after { transform: translateX(120%); }
      .pn-btn:hover:not(:disabled) { filter: brightness(1.1); transform: translateY(-2px); background-position: 100% 0;
        box-shadow: 0 12px 32px rgba(124,92,252,.5); }
      .pn-btn:active:not(:disabled) { transform: translateY(0); }
      .pn-btn:disabled { opacity: .5; cursor: not-allowed; transform: none; filter: none; animation: none; }

      /* ── Alerts ── */
      .pn-err {
        background: #fef2f2; border: 1px solid #fecaca;
        border-radius: 10px; padding: .65rem .9rem;
        font-size: .8rem; color: #dc2626; margin-bottom: .85rem;
        display: none; line-height: 1.5;
      }
      .pn-ok {
        background: #f0fdf4; border: 1px solid #bbf7d0;
        border-radius: 10px; padding: .65rem .9rem;
        font-size: .8rem; color: #16a34a; margin-bottom: .85rem; display: none;
      }

      /* ── Switch link ── */
      .pn-switch {
        text-align: center; font-size: .8rem; color: #9ca3af; margin-top: 1rem;
      }
      .pn-switch a { color: #7c5cfc; font-weight: 700; text-decoration: none; cursor: pointer; transition: color .2s; }
      .pn-switch a:hover { color: #5b3fd4; text-decoration: underline; }

      /* ── Forgot pw ── */
      .pn-forgot {
        text-align: right; font-size: .72rem; margin-top: -.4rem; margin-bottom: .85rem;
        color: #9ca3af;
      }
      .pn-forgot a { color: #7c5cfc; text-decoration: none; cursor: pointer; transition: color .2s; }
      .pn-forgot a:hover { color: #5b3fd4; text-decoration: underline; }

      /* ── OTP inputs ── */
      .pn-otp-wrap { display: flex; gap: .5rem; justify-content: center; margin-bottom: 1.4rem; }
      .pn-otp-input {
        width: 44px; height: 52px; text-align: center; font-size: 1.35rem; font-weight: 800;
        background: #f9f8ff; border: 1.5px solid #e5e0ff;
        border-radius: 12px; color: #12103a; outline: none; font-family: inherit;
        transition: border-color .2s, box-shadow .2s;
      }
      .pn-otp-input:focus { border-color: #7c5cfc; box-shadow: 0 0 0 3px rgba(124,92,252,.12); }
      .pn-otp-resend { text-align: center; font-size: .77rem; color: #9ca3af; margin-top: .75rem; }
      .pn-otp-resend a { color: #7c5cfc; font-weight: 700; cursor: pointer; text-decoration: none; }

      /* ── Success screen ── */
      .pn-success { text-align: center; padding: 1rem 0; }
      .pn-success-icon { font-size: 4rem; margin-bottom: 1rem; animation: pn-pop .5s cubic-bezier(.34,1.56,.64,1); }
      @keyframes pn-pop { from { transform: scale(0); opacity: 0; } to { transform: scale(1); opacity: 1; } }
      .pn-success h3 { font-size: 1.5rem; font-weight: 900; color: #12103a; margin-bottom: .5rem; }
      .pn-success p { font-size: .85rem; color: #6b7280; margin-bottom: 1.5rem; line-height: 1.6; }

      /* ── Mentor info note ── */
      .pn-info-note {
        background: #faf9ff; border: 1px solid #e5e0ff;
        border-radius: 12px; padding: .85rem 1rem; font-size: .78rem;
        color: #6b7280; line-height: 1.6; margin-bottom: 1rem;
      }
      .pn-info-note strong { color: #7c5cfc; }

      /* ── Referral code field ── */
      .pn-ref-wrap { position: relative; }
      .pn-ref-wrap input { padding-right: 2.8rem !important; text-transform: uppercase; letter-spacing: .05em; }
      .pn-ref-spin {
        position: absolute; right: .8rem; top: 50%; transform: translateY(-50%);
        width: 14px; height: 14px;
        border: 2px solid rgba(124,92,252,.18); border-top-color: #7c5cfc;
        border-radius: 50%; animation: pn-spin .7s linear infinite; display: none;
      }
      @keyframes pn-spin { to { transform: translateY(-50%) rotate(360deg); } }
      .pn-ref-icon {
        position: absolute; right: .8rem; top: 50%; transform: translateY(-50%);
        font-size: .9rem; pointer-events: none; display: none;
        line-height: 1; font-style: normal;
      }
      /* Input state variants */
      .pn-field input.pn-valid   { border-color: #22c55e !important; box-shadow: 0 0 0 3px rgba(34,197,94,.09) !important; }
      .pn-field input.pn-invalid { border-color: #ef4444 !important; box-shadow: 0 0 0 3px rgba(239,68,68,.09) !important; }
      .pn-field input.pn-loading { border-color: rgba(245,158,11,.45) !important; box-shadow: 0 0 0 3px rgba(245,158,11,.08) !important; }
      /* Alert icon prefix */
      .pn-err::before { content: '⚠ '; }

      /* ── Responsive ── */
      @media (max-width: 480px) {
        .pn-box { padding: 1.8rem 1.3rem; border-radius: 20px; }
        .pn-role-cards { grid-template-columns: 1fr; }
        .pn-title { font-size: 1.4rem; }
        .pn-field-row { grid-template-columns: 1fr; }
      }

      /* ── Profile dropdown extra styles ── */
      .pd-header {
        display: flex; align-items: center; gap: .75rem;
        padding: .75rem 1rem .6rem; pointer-events: none;
      }
      .pd-avatar-sm {
        width: 36px; height: 36px; border-radius: 50%;
        background: linear-gradient(135deg,#7c5cfc,#3d6bff);
        display: flex; align-items: center; justify-content: center;
        font-size: .9rem; font-weight: 800; color: #fff; flex-shrink: 0; overflow: hidden;
      }
      .pd-user-name { font-size: .85rem; font-weight: 700; color: var(--txt); line-height: 1.2; }
      .pd-user-email { font-size: .72rem; color: var(--txt3); }
      .pd-divider { height: 1px; background: var(--border); margin: .3rem 0; }

      /* ── Footer extra styles ── */
      .footer-tagline { font-size: .84rem; color: var(--txt4); line-height: 1.75; max-width: 280px; margin-top: .75rem; }
      .footer-contacts { display: flex; flex-direction: column; gap: .45rem; margin-top: 1rem; }
      .footer-ssl-badge {
        display: inline-flex; align-items: center; gap: .4rem;
        font-size: .72rem; color: var(--txt4); font-weight: 500; margin-top: .75rem;
        background: rgba(74,222,128,.06); border: 1px solid rgba(74,222,128,.15);
        border-radius: 999px; padding: .25rem .65rem;
      }

      /* ── Nav scrolled state ── */
      nav.scrolled {
        height: 66px;
        background: rgba(6,4,20,0.92) !important;
        box-shadow: 0 4px 24px rgba(0,0,0,.35);
      }
      :root[data-theme="light"] nav.scrolled {
        background: rgba(255,255,255,0.96) !important;
      }



      /* ── Active nav link indicator ── */
      .nav-link-item.active {
        color: var(--txt) !important;
        font-weight: 700 !important;
      }
      .nav-link-item { color: var(--txt3); font-size: .875rem; font-weight: 500; text-decoration: none; letter-spacing: .02em; position: relative; padding-bottom: 2px; transition: color .25s; }
      .nav-link-item::after { content: ''; position: absolute; bottom: -2px; left: 0; width: 0; height: 1.5px; background: var(--grad); border-radius: 2px; transition: width .3s cubic-bezier(.4,0,.2,1); }
      .nav-link-item:hover { color: var(--txt); }
      .nav-link-item:hover::after, .nav-link-item.active::after { width: 100%; }
    `;
    document.head.appendChild(style);

    /* ── HTML ── */
    const wrap = document.createElement('div');
    wrap.id = 'pn-auth-modal';
    wrap.setAttribute('role', 'dialog');
    wrap.setAttribute('aria-modal', 'true');
    wrap.setAttribute('aria-label', 'Sign in to SkillUpNow');

    wrap.innerHTML = `
      <div class="pn-box" role="document">
        <button class="pn-close" id="pn-close-btn" aria-label="Close">✕</button>

        <!-- ═══════════ WELCOME / LOGIN ROLE SELECT ═══════════ -->
        <div id="pn-v-welcome">
          <div class="pn-brand">
            <div class="pn-brand-logo"><svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
            <span class="pn-brand-name">SkillUpNow</span>
            <span class="pn-badge">Secure</span>
          </div>
          <div class="pn-title">Welcome <span>Back</span></div>
          <div class="pn-sub">Sign in to continue your learning journey</div>

          <div class="pn-divider-text">SIGN IN AS</div>

          <div class="pn-role-cards">
            <div class="pn-role-card" onclick="window._pnView('student-login')" role="button" tabindex="0">
              <span class="pn-role-icon">📚</span>
              <div class="pn-role-name">Student</div>
              <div class="pn-role-desc">Access your learning dashboard</div>
            </div>
            <div class="pn-role-card" onclick="window._pnView('mentor-login')" role="button" tabindex="0">
              <span class="pn-role-icon">🎓</span>
              <div class="pn-role-name">Mentor</div>
              <div class="pn-role-desc">Manage batches &amp; classes</div>
            </div>
          </div>

          <div class="pn-switch">New to SkillUpNow? <a onclick="window._pnView('signup-role')">Create Free Account →</a></div>
        </div>

        <!-- ═══════════ STUDENT LOGIN ═══════════ -->
        <div id="pn-v-student-login" style="display:none">
          <button class="pn-back" onclick="window._pnView('welcome')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg> Back</button>
          <div class="pn-title">Student <span>Login</span></div>
          <div class="pn-sub">Access your courses and learning dashboard</div>

          <div class="pn-err" id="pn-sl-err"></div>
          <div class="pn-field"><label>Email Address</label><input type="email" id="pn-sl-email" placeholder="you@example.com" autocomplete="email"></div>
          <div class="pn-field">
            <label>Password</label>
            <div class="pn-pw-wrap">
              <input type="password" id="pn-sl-pw" placeholder="Your password" autocomplete="current-password">
              <button class="pn-pw-toggle" type="button" onclick="window._pnTogglePw('pn-sl-pw',this)" title="Show/hide password" aria-label="Toggle password visibility"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>
            </div>
          </div>
          <div class="pn-forgot"><a onclick="window._pnView('forgot-pw')">Forgot password?</a></div>
          <button class="pn-btn" id="pn-sl-btn" onclick="window._pnStudentLogin()">Sign In to Dashboard</button>
          <div class="pn-switch">No account? <a onclick="window._pnView('signup-student')">Sign up free →</a></div>
        </div>

        <!-- ═══════════ MENTOR LOGIN ═══════════ -->
        <div id="pn-v-mentor-login" style="display:none">
          <button class="pn-back" onclick="window._pnView('welcome')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg> Back</button>
          <div class="pn-title">Mentor <span>Login</span></div>
          <div class="pn-sub">Access your teaching portal and batch management</div>

          <div class="pn-err" id="pn-ml-err"></div>
          <div class="pn-field"><label>Email Address</label><input type="email" id="pn-ml-email" placeholder="you@example.com" autocomplete="email"></div>
          <div class="pn-field">
            <label>Password</label>
            <div class="pn-pw-wrap">
              <input type="password" id="pn-ml-pw" placeholder="Your password" autocomplete="current-password">
              <button class="pn-pw-toggle" type="button" onclick="window._pnTogglePw('pn-ml-pw',this)" title="Show/hide password" aria-label="Toggle password visibility"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>
            </div>
          </div>
          <div class="pn-forgot"><a onclick="window._pnView('forgot-pw')">Forgot password?</a></div>
          <button class="pn-btn" id="pn-ml-btn" onclick="window._pnMentorLogin()">Sign In to Portal</button>
          <div class="pn-switch">Not a mentor yet? <a href="javascript:void(0)" onclick="window._pnClose();window.location.href=(window.profileNav?.pagesPfx??'pages/')+'mentor-signup'">Apply to become one →</a></div>
        </div>

        <!-- ═══════════ FORGOT PASSWORD ═══════════ -->
        <div id="pn-v-forgot-pw" style="display:none">
          <button class="pn-back" onclick="window._pnView('welcome')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg> Back</button>
          <div class="pn-title">Reset <span>Password</span></div>
          <div class="pn-sub">Enter your email and we'll send you a secure reset link</div>
          <div class="pn-err" id="pn-fp-err"></div>
          <div class="pn-ok"  id="pn-fp-ok" style="display:none;background:rgba(74,222,128,.1);border:1px solid rgba(74,222,128,.25);border-radius:10px;padding:.75rem 1rem;font-size:.84rem;color:#4ade80;margin-bottom:1rem;"></div>
          <div class="pn-field"><label>Email Address</label><input type="email" id="pn-fp-email" placeholder="you@example.com" autocomplete="email"></div>
          <button class="pn-btn" id="pn-fp-btn" onclick="window._pnSendReset()">Send Reset Link</button>
          <div class="pn-switch">Remember your password? <a onclick="window._pnView('welcome')">Back to sign in →</a></div>
        </div>

        <!-- ═══════════ SIGNUP ROLE SELECT ═══════════ -->
        <div id="pn-v-signup-role" style="display:none">
          <button class="pn-back" onclick="window._pnView('welcome')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg> Back</button>
          <div class="pn-title">Join <span>SkillUpNow</span></div>
          <div class="pn-sub">Create your free account — choose your role to get started</div>

          <div class="pn-divider-text">CREATE ACCOUNT AS</div>

          <div class="pn-role-cards">
            <div class="pn-role-card" onclick="window._pnView('signup-student')" role="button" tabindex="0">
              <span class="pn-role-icon">📚</span>
              <div class="pn-role-name">Student</div>
              <div class="pn-role-desc">Enroll in courses &amp; learn</div>
            </div>
            <div class="pn-role-card" onclick="window._pnClose();window.location.href=(window.profileNav?.pagesPfx??'pages/')+'mentor-signup'" role="button" tabindex="0">
              <span class="pn-role-icon">🎓</span>
              <div class="pn-role-name">Mentor</div>
              <div class="pn-role-desc">Teach &amp; earn with SkillUpNow</div>
            </div>
          </div>
          <div class="pn-switch">Already have an account? <a onclick="window._pnView('welcome')">Sign in →</a></div>
        </div>

        <!-- ═══════════ STUDENT SIGNUP ═══════════ -->
        <div id="pn-v-signup-student" style="display:none">
          <button class="pn-back" onclick="window._pnView('signup-role')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg> Back</button>
          <div class="pn-title">Student <span>Sign Up</span></div>
          <div class="pn-sub">Start your learning journey — it's free</div>

          <div class="pn-err" id="pn-ss-err"></div>
          <div class="pn-ok"  id="pn-ss-ok"></div>

          <!-- Row 1: First & Last Name side by side -->
          <div class="pn-field-row">
            <div class="pn-field">
              <label>First Name <span class="pn-req">*</span></label>
              <input type="text" id="pn-ss-fname" placeholder="First name" autocomplete="given-name" oninput="window._pnValidateField(this,'text')">
              <div class="pn-field-hint" id="pn-ss-fname-h"></div>
            </div>
            <div class="pn-field">
              <label>Last Name <span class="pn-req">*</span></label>
              <input type="text" id="pn-ss-lname" placeholder="Last name" autocomplete="family-name" oninput="window._pnValidateField(this,'text')">
              <div class="pn-field-hint" id="pn-ss-lname-h"></div>
            </div>
          </div>

          <!-- Row 2: Email -->
          <div class="pn-field">
            <label>Email Address <span class="pn-req">*</span></label>
            <input type="email" id="pn-ss-email" placeholder="you@example.com" autocomplete="email" oninput="window._pnValidateField(this,'email')">
            <div class="pn-field-hint" id="pn-ss-email-h"></div>
          </div>

          <!-- Row 3: Phone -->
          <div class="pn-field">
            <label>Phone Number <span class="pn-req">*</span> <span style="font-size:.62rem;color:#9ca3af;text-transform:none;letter-spacing:0;">(10-digit Indian mobile)</span></label>
            <input type="tel" id="pn-ss-phone" placeholder="9876543210" autocomplete="tel" maxlength="10" oninput="window._pnValidateField(this,'phone')">
            <div class="pn-field-hint" id="pn-ss-phone-h"></div>
          </div>

          <!-- Row 4: Password + Confirm Password side by side -->
          <div class="pn-field-row">
            <div class="pn-field">
              <label>Password <span class="pn-req">*</span></label>
              <div class="pn-pw-wrap">
                <input type="password" id="pn-ss-pw" placeholder="Min. 8 chars, A-Z, 0-9" autocomplete="new-password"
                  oninput="window._pnStrength('pn-ss-pw','pn-ss-strength','pn-ss-strength-lbl','pn-ss-hints');window._pnCheckPwMatch('pn-ss-pw','pn-ss-cpw','pn-ss-cpw-h')">
                <button class="pn-pw-toggle" type="button" onclick="window._pnTogglePw('pn-ss-pw',this)" title="Show/hide password" aria-label="Toggle password visibility"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>
              </div>
              <div class="pn-strength" id="pn-ss-strength"></div>
              <div class="pn-strength-label" id="pn-ss-strength-lbl"></div>
              <div class="pn-pw-hints" id="pn-ss-hints" style="margin-top:.3rem;">
                <span class="pn-pw-hint" data-rule="len">8+ chars</span>
                <span class="pn-pw-hint" data-rule="upper">A-Z</span>
                <span class="pn-pw-hint" data-rule="num">0-9</span>
              </div>
            </div>
            <div class="pn-field">
              <label>Confirm Password <span class="pn-req">*</span></label>
              <div class="pn-pw-wrap">
                <input type="password" id="pn-ss-cpw" placeholder="Re-enter password" autocomplete="new-password"
                  oninput="window._pnCheckPwMatch('pn-ss-pw','pn-ss-cpw','pn-ss-cpw-h')">
                <button class="pn-pw-toggle" type="button" onclick="window._pnTogglePw('pn-ss-cpw',this)" title="Show/hide password" aria-label="Toggle password visibility"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>
              </div>
              <div class="pn-field-hint" id="pn-ss-cpw-h" aria-live="polite"></div>
            </div>
          </div>

          <!-- Referral Code (optional) -->
          <div class="pn-field">
            <label style="display:flex;align-items:center;gap:.4rem;">
              Referral Code
              <span style="font-size:.6rem;background:rgba(124,92,252,.1);border:1px solid rgba(124,92,252,.22);border-radius:999px;padding:.06rem .42rem;color:rgba(124,92,252,.7);font-weight:600;text-transform:uppercase;letter-spacing:.05em;">Optional</span>
            </label>
            <div class="pn-ref-wrap">
              <input type="text" id="pn-ss-ref" placeholder="Enter code if you have one"
                autocomplete="off" spellcheck="false"
                oninput="window._pnRefCodeInput('pn-ss-ref','pn-ss-ref-h','pn-ss-ref-icon','pn-ss-ref-spin')"
                onblur="window._pnValidateRefCode(this.value,'pn-ss-ref','pn-ss-ref-h','pn-ss-ref-icon','pn-ss-ref-spin')">
              <div class="pn-ref-spin" id="pn-ss-ref-spin" aria-hidden="true"></div>
              <i class="pn-ref-icon" id="pn-ss-ref-icon" aria-hidden="true"></i>
            </div>
            <div class="pn-field-hint" id="pn-ss-ref-h" aria-live="polite"></div>
          </div>

          <label class="pn-terms">
            <input type="checkbox" id="pn-ss-terms">
            <span class="pn-terms-check">✓</span>
            I agree to the <a href="#" onclick="return false">Terms of Service</a> and <a href="#" onclick="return false">Privacy Policy</a>
          </label>
          <button class="pn-btn" id="pn-ss-btn" onclick="window._pnStudentRegister()">Create Student Account</button>
          <div class="pn-switch">Already have an account? <a onclick="window._pnView('student-login')">Sign in →</a></div>
        </div>

        <!-- ═══════════ MENTOR SIGNUP (basic) ═══════════ -->
        <div id="pn-v-signup-mentor" style="display:none">
          <button class="pn-back" onclick="window._pnView('signup-role')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg> Back</button>
          <div class="pn-title">Mentor <span>Sign Up</span></div>
          <div class="pn-sub">Create your account, then complete your mentor profile</div>

          <div class="pn-info-note">
            <strong>Two-step process:</strong> First create your account below, then you'll be guided to submit your qualifications, PAN card, Aadhaar, certificates, and other documents for admin approval.
          </div>

          <div class="pn-err" id="pn-sm-err"></div>
          <div class="pn-ok"  id="pn-sm-ok"></div>

          <div class="pn-field-row">
            <div class="pn-field"><label>First Name <span class="pn-req">*</span></label><input type="text" id="pn-sm-fname" placeholder="First name" autocomplete="given-name" oninput="window._pnValidateField(this,'text')"></div>
            <div class="pn-field"><label>Last Name <span class="pn-req">*</span></label><input type="text" id="pn-sm-lname" placeholder="Last name" autocomplete="family-name" oninput="window._pnValidateField(this,'text')"></div>
          </div>
          <div class="pn-field"><label>Email Address <span class="pn-req">*</span></label><input type="email" id="pn-sm-email" placeholder="you@example.com" autocomplete="email" oninput="window._pnValidateField(this,'email')"></div>
          <div class="pn-field"><label>Phone Number <span class="pn-req">*</span> <span style="font-size:.62rem;color:#9ca3af;text-transform:none;letter-spacing:0;">(10-digit Indian mobile)</span></label><input type="tel" id="pn-sm-phone" placeholder="9876543210" autocomplete="tel" maxlength="10" oninput="window._pnValidateField(this,'phone')"></div>
          <div class="pn-field"><label>Primary Expertise <span class="pn-req">*</span></label>
            <select id="pn-sm-expertise">
              <option value="">Select your main domain…</option>
              <option>Web Development</option><option>Data Science / ML</option>
              <option>Cloud Computing</option><option>DevOps / SRE</option>
              <option>Cybersecurity</option><option>Mobile Development</option>
              <option>UI/UX Design</option><option>Digital Marketing</option>
              <option>Finance / Accounting</option><option>Other</option>
            </select>
          </div>
          <div class="pn-field">
            <label>Password <span class="pn-req">*</span> <span style="font-size:.62rem;color:#9ca3af;text-transform:none;letter-spacing:0;">(min. 8 chars, A-Z, a-z, 0-9)</span></label>
            <div class="pn-pw-wrap">
              <input type="password" id="pn-sm-pw" placeholder="Create a strong password" autocomplete="new-password" oninput="window._pnStrength('pn-sm-pw','pn-sm-strength','pn-sm-strength-lbl',null)">
              <button class="pn-pw-toggle" type="button" onclick="window._pnTogglePw('pn-sm-pw',this)" title="Show/hide password" aria-label="Toggle password visibility"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>
            </div>
            <div class="pn-strength" id="pn-sm-strength"></div>
            <div class="pn-strength-label" id="pn-sm-strength-lbl"></div>
          </div>
          <div class="pn-field">
            <label>Confirm Password <span class="pn-req">*</span></label>
            <div class="pn-pw-wrap">
              <input type="password" id="pn-sm-cpw" placeholder="Re-enter your password" autocomplete="new-password"
                oninput="window._pnCheckPwMatch('pn-sm-pw','pn-sm-cpw','pn-sm-cpw-h')">
              <button class="pn-pw-toggle" type="button" onclick="window._pnTogglePw('pn-sm-cpw',this)" title="Show/hide password" aria-label="Toggle password visibility"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>
            </div>
            <div class="pn-field-hint" id="pn-sm-cpw-h" aria-live="polite"></div>
          </div>
          <label class="pn-terms">
            <input type="checkbox" id="pn-sm-terms">
            <span class="pn-terms-check">✓</span>
            I agree to the <a href="#" onclick="return false">Mentor Terms</a> and understand the approval process
          </label>
          <button class="pn-btn" id="pn-sm-btn" onclick="window._pnMentorRegister()">Create & Continue to Application →</button>
          <div class="pn-switch">Already a mentor? <a onclick="window._pnView('mentor-login')">Sign in →</a></div>
        </div>

        <!-- ═══════════ EMAIL VERIFICATION SENT ═══════════ -->
        <div id="pn-v-email-sent" style="display:none">
          <div class="pn-success">
            <div class="pn-success-icon">📧</div>
            <h3>Check Your Inbox</h3>
            <p id="pn-email-sent-msg">A verification link has been sent to your email address. Click the link to activate your account and then sign in.</p>
            <div style="background:rgba(124,92,252,.06);border:1px solid rgba(124,92,252,.15);border-radius:12px;padding:.85rem 1rem;font-size:.78rem;color:inherit;margin-bottom:1.2rem;text-align:left;line-height:1.7;">
              <strong>Steps to complete sign-up:</strong><br>
              1. Open the verification email from SkillUpNow<br>
              2. Click the confirmation link<br>
              3. Return here and sign in
            </div>
            <button class="pn-btn" onclick="window._pnView('student-login')">Go to Sign In →</button>
            <div class="pn-switch" style="margin-top:.75rem;font-size:.75rem;">Didn't receive the email? Check your spam folder or <a onclick="window._pnView('signup-student')">try again</a></div>
          </div>
        </div>

        <!-- ═══════════ SUCCESS SCREEN ═══════════ -->
        <div id="pn-v-success" style="display:none">
          <div class="pn-success">
            <div class="pn-success-icon" id="pn-success-icon">🎉</div>
            <h3 id="pn-success-title">You're In!</h3>
            <p id="pn-success-msg">Your account has been created. Redirecting you now…</p>
            <button class="pn-btn" id="pn-success-btn" onclick="window._pnClose()">Continue →</button>
          </div>
        </div>

      </div><!-- /.pn-box -->
    `;
    document.body.appendChild(wrap);

    /* ── Close button ── */
    document.getElementById('pn-close-btn').addEventListener('click', () => window._pnClose());

    /* ── Close on backdrop click ── */
    wrap.addEventListener('click', e => { if (e.target === wrap) window._pnClose(); });

    /* ── Keyboard ── */
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') window._pnClose();
      if (e.key === 'Enter' && e.target.classList.contains('pn-role-card')) e.target.click();
    });

    /* ── Enter key submit in forms ── */
    wrap.addEventListener('keydown', e => {
      if (e.key !== 'Enter' || e.target.tagName === 'BUTTON') return;
      const active = ['pn-v-student-login','pn-v-mentor-login','pn-v-signup-student','pn-v-signup-mentor']
        .find(id => { const el = document.getElementById(id); return el && el.style.display !== 'none'; });
      if (!active) return;
      const map = {
        'pn-v-student-login': () => window._pnStudentLogin(),
        'pn-v-mentor-login':  () => window._pnMentorLogin(),
        'pn-v-signup-student':() => window._pnStudentRegister(),
        'pn-v-signup-mentor': () => window._pnMentorRegister(),
      };
      if (map[active]) map[active]();
    });

    /* ══════════════════════════════════════════
       GLOBAL HANDLER FUNCTIONS
       ══════════════════════════════════════════ */
    const self = this;

    /* Referral code validation state — reset on every view switch */
    let _pnRefState = null;  // null | 'valid' | 'invalid'
    let _pnRefData  = null;  // row from referral_codes table if valid

    const ALL_VIEWS = ['pn-v-welcome','pn-v-student-login','pn-v-mentor-login',
                       'pn-v-forgot-pw',
                       'pn-v-signup-role','pn-v-signup-student','pn-v-signup-mentor',
                       'pn-v-email-sent','pn-v-success'];

    window._pnView = (view) => {
      ALL_VIEWS.forEach(id => {
        const el = document.getElementById(id);
        if (el) el.style.display = (id === 'pn-v-' + view) ? '' : 'none';
      });
      // Clear alerts when switching
      ['pn-sl-err','pn-ml-err','pn-fp-err','pn-fp-ok','pn-ss-err','pn-ss-ok','pn-sm-err','pn-sm-ok','pn-otp-err'].forEach(id => {
        const el = document.getElementById(id);
        if (el) { el.style.display = 'none'; el.textContent = ''; }
      });
      // Reset forgot-pw button if re-entering the view
      const fpBtn = document.getElementById('pn-fp-btn');
      if (fpBtn) { fpBtn.disabled = false; fpBtn.textContent = 'Send Reset Link'; }
      // Reset referral code state and clear hint/input on every view change
      _pnRefState = null; _pnRefData = null;
      const refInp  = document.getElementById('pn-ss-ref');
      const refHint = document.getElementById('pn-ss-ref-h');
      const refIcon = document.getElementById('pn-ss-ref-icon');
      const refSpin = document.getElementById('pn-ss-ref-spin');
      if (refInp)  { refInp.value = ''; refInp.classList.remove('pn-valid','pn-invalid','pn-loading'); }
      if (refHint) { refHint.textContent = ''; refHint.className = 'pn-field-hint'; }
      if (refIcon) { refIcon.style.display = 'none'; refIcon.textContent = ''; }
      if (refSpin) refSpin.style.display = 'none';
      // Clear password mismatch hints
      ['pn-ss-cpw-h','pn-sm-cpw-h'].forEach(id => {
        const el = document.getElementById(id);
        if (el) { el.textContent = ''; el.className = 'pn-field-hint'; }
      });
      // Clear all form input values and reset invalid/valid styles on every view switch
      const viewInputIds = [
        'pn-sl-email','pn-sl-pw',
        'pn-ml-email','pn-ml-pw',
        'pn-fp-email',
        'pn-ss-fname','pn-ss-lname','pn-ss-email','pn-ss-phone','pn-ss-pw','pn-ss-cpw',
        'pn-sm-fname','pn-sm-lname','pn-sm-email','pn-sm-phone','pn-sm-pw','pn-sm-cpw'
      ];
      viewInputIds.forEach(id => {
        const el = document.getElementById(id);
        if (el) { el.value = ''; el.classList.remove('invalid','valid'); }
      });
      // Reset checkboxes
      ['pn-ss-terms','pn-sm-terms'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.checked = false;
      });
      // Reset select dropdowns
      ['pn-sm-expertise'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.selectedIndex = 0;
      });
      // Reset submit buttons to their default states
      const btnMap = {
        'pn-sl-btn':  ['Sign In', false],
        'pn-ml-btn':  ['Sign In to Portal', false],
        'pn-ss-btn':  ['Create Student Account', false],
        'pn-sm-btn':  ['Create & Continue to Application →', false]
      };
      Object.entries(btnMap).forEach(([id, [txt, dis]]) => {
        const el = document.getElementById(id);
        if (el) { el.textContent = txt; el.disabled = dis; }
      });
    };

    window._pnClose = () => {
      document.getElementById('pn-auth-modal')?.classList.remove('pn-open');
    };

    window._pnOpen = (startView = 'welcome') => {
      window._pnView(startView);
      document.getElementById('pn-auth-modal')?.classList.add('pn-open');
    };

    const _eyeOpen  = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>`;
    const _eyeClosed = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>`;

    window._pnTogglePw = (inputId, btn) => {
      const inp = document.getElementById(inputId);
      if (!inp) return;
      const isText = inp.type === 'text';
      inp.type = isText ? 'password' : 'text';
      btn.innerHTML = isText ? _eyeOpen : _eyeClosed;
      btn.style.color = isText ? '' : 'var(--v1, #7c5cfc)';
    };

    /* ── Forgot password — pre-fill email from whichever login was active ── */
    window._pnForgotPw = () => {
      const emailEl = document.getElementById('pn-sl-email') || document.getElementById('pn-ml-email');
      const fp = document.getElementById('pn-fp-email');
      if (fp && emailEl?.value) fp.value = emailEl.value;
      window._pnView('forgot-pw');
    };

    window._pnSendReset = async () => {
      const email = (document.getElementById('pn-fp-email')?.value || '').trim();
      const errEl = document.getElementById('pn-fp-err');
      const okEl  = document.getElementById('pn-fp-ok');
      const btn   = document.getElementById('pn-fp-btn');

      /* Clear previous messages */
      _pnClearMsg(errEl);
      _pnClearMsg(okEl);

      /* Basic validation */
      if (!email) {
        return _pnErr(errEl, 'Please enter your email address.');
      }
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return _pnErr(errEl, 'Please enter a valid email address (e.g. you@gmail.com).');
      }

      /* Supabase availability check */
      const client = window.supabaseConfig?.client;
      if (!client) {
        return _pnErr(errEl, 'Auth service not ready. Please refresh the page.');
      }

      /* Disable button and show loading state */
      btn.disabled = true;
      btn.textContent = 'Sending…';

      try {
        const { error } = await client.auth.resetPasswordForEmail(email, {
          redirectTo: window.location.origin + '/pages/reset-password.html'
        });

        if (error) {
          /* Map common Supabase error messages to friendly text */
          const msg = error.message || '';
          if (msg.includes('60 seconds') || msg.includes('rate') || msg.includes('too many')) {
            throw new Error('Too many requests. Please wait 60 seconds before trying again.');
          }
          throw error;
        }

        /* Success */
        okEl.textContent = '✓ Reset link sent to ' + email + '. Check your inbox and spam folder.';
        okEl.style.display = 'block';
        btn.textContent = 'Link Sent ✓';
        btn.disabled = true; /* Keep disabled to prevent double-send */

      } catch (e) {
        btn.disabled = false;
        btn.textContent = 'Send Reset Link';
        _pnErr(errEl, e.message || 'Could not send reset email. Please try again.');
      }
    };

    /* ── Field inline validation ── */
    window._pnValidateField = (input, type) => {
      const val = input.value.trim();
      const hintEl = document.getElementById(input.id + '-h');
      const showHint = (msg, isErr) => {
        if (!hintEl) return;
        hintEl.textContent = msg; hintEl.className = 'pn-field-hint show ' + (isErr ? 'err' : 'ok');
      };
      if (!val) { input.className = input.className.replace(/ ?(valid|invalid)/g,''); if(hintEl) hintEl.className='pn-field-hint'; return; }
      if (type === 'email') {
        const ok = pnEmailRe.test(val);
        input.classList.toggle('valid', ok); input.classList.toggle('invalid', !ok);
        showHint(ok ? '✓ Valid email' : '✗ Enter a valid email (e.g. you@gmail.com)', !ok);
      } else if (type === 'phone') {
        const normalized = val.replace(/\D/g,'');
        const ok = pnPhoneRe.test(normalized);
        input.classList.toggle('valid', ok); input.classList.toggle('invalid', !ok);
        showHint(ok ? '✓ Valid phone number' : '✗ Must be 10 digits starting with 6–9', !ok);
      } else if (type === 'text') {
        const ok = val.length >= 2;
        input.classList.toggle('valid', ok); input.classList.toggle('invalid', !ok);
        if (!ok) showHint('✗ Too short', true); else if (hintEl) hintEl.className='pn-field-hint';
      }
    };

    /* ── Password strength ── */
    window._pnStrength = (inputId, barId, lblId, hintsId) => {
      const val = document.getElementById(inputId)?.value || '';
      const rules = {
        len:     val.length >= 8,
        upper:   /[A-Z]/.test(val),
        num:     /\d/.test(val),
        special: /[^A-Za-z0-9]/.test(val),
      };
      const score = Object.values(rules).filter(Boolean).length;
      const bar = document.getElementById(barId);
      const lbl = document.getElementById(lblId);
      if (bar) {
        const w = ['0%','30%','55%','80%','100%'][score];
        const c = ['rgba(255,255,255,.06)','#ef4444','#f59e0b','#22c55e','#4ade80'][score];
        bar.style.width = w; bar.style.background = c;
      }
      if (lbl) {
        const labels = ['','Weak','Fair','Good','Strong'];
        lbl.textContent = val ? (labels[score] || '') : '';
        lbl.style.color = ['','#ef4444','#f59e0b','#22c55e','#4ade80'][score];
      }
      if (hintsId) {
        document.querySelectorAll(`#${hintsId} .pn-pw-hint`).forEach(h => {
          h.classList.toggle('ok', !!rules[h.dataset.rule]);
        });
      }
    };

    /* ── Student Login ── */
    window._pnStudentLogin = async () => {
      const email = document.getElementById('pn-sl-email')?.value?.trim();
      const pw    = document.getElementById('pn-sl-pw')?.value;
      const err   = document.getElementById('pn-sl-err');
      const btn   = document.getElementById('pn-sl-btn');
      if (!email || !pw) { return _pnErr(err, 'Email and password are required.'); }
      btn.disabled = true; btn.textContent = 'Signing in…';
      err.style.display = 'none';
      try {
        if (!window.supabaseConfig) throw new Error('Auth service not ready. Refresh and try again.');
        const r = await window.supabaseConfig.signIn(email, pw);
        if (!r.success) {
          const raw = (r.error || '').toLowerCase();
          if (raw.includes('invalid') || raw.includes('invalid_credentials') || raw.includes('wrong') || raw.includes('incorrect')) {
            throw new Error('Incorrect email or password. Please check your details and try again.');
          } else if (raw.includes('rate') || raw.includes('too many')) {
            throw new Error('Too many login attempts. Please wait a few minutes before trying again.');
          } else if (raw.includes('email') && (raw.includes('confirm') || raw.includes('verified') || raw.includes('not confirmed'))) {
            throw new Error('Please verify your email address first. Check your inbox for a verification link.');
          } else if (raw.includes('banned') || raw.includes('disabled') || raw.includes('deactivated')) {
            throw new Error('This account has been disabled. Please contact support.');
          } else if (raw.includes('network') || raw.includes('fetch')) {
            throw new Error('Connection error. Please check your internet and try again.');
          }
          throw new Error(r.error || 'Incorrect email or password. Please try again.');
        }
        const user = r.data?.user || r.user;
        if (!user) throw new Error('Login failed — no user returned.');
        // Role check: block mentors from using student login
        const { data: profile } = await window.supabaseConfig.client
          .from('user_profiles').select('role').eq('user_id', user.id).maybeSingle();
        if (profile?.role === 'mentor') {
          await window.supabaseConfig.client.auth.signOut();
          throw new Error('This is a Mentor account. Please use Mentor Login to sign in.');
        }
        if (profile?.role === 'admin' || profile?.role === 'super_admin') {
          await window.supabaseConfig.client.auth.signOut();
          throw new Error('Admin accounts must use the Admin Login page.');
        }
        self.currentUser = user;
        self.showLoggedInUI();
        window._pnClose();
        window.location.reload();
      } catch(e) { _pnErr(err, e.message); btn.disabled = false; btn.textContent = 'Sign In to Dashboard'; }
    };

    /* ── Mentor Login ── */
    window._pnMentorLogin = async () => {
      const email = document.getElementById('pn-ml-email')?.value?.trim();
      const pw    = document.getElementById('pn-ml-pw')?.value;
      const err   = document.getElementById('pn-ml-err');
      const btn   = document.getElementById('pn-ml-btn');
      if (!email || !pw) { return _pnErr(err, 'Email and password are required.'); }
      btn.disabled = true; btn.textContent = 'Signing in…';
      err.style.display = 'none';
      try {
        if (!window.supabaseConfig) throw new Error('Auth service not ready. Refresh and try again.');
        const r = await window.supabaseConfig.signIn(email, pw);
        if (!r.success) {
          const raw = (r.error || '').toLowerCase();
          if (raw.includes('invalid') || raw.includes('invalid_credentials') || raw.includes('wrong') || raw.includes('incorrect')) {
            throw new Error('Incorrect email or password. Please check your details and try again.');
          } else if (raw.includes('rate') || raw.includes('too many')) {
            throw new Error('Too many login attempts. Please wait a few minutes before trying again.');
          } else if (raw.includes('email') && (raw.includes('confirm') || raw.includes('verified') || raw.includes('not confirmed'))) {
            throw new Error('Please verify your email address first. Check your inbox for a verification link.');
          } else if (raw.includes('banned') || raw.includes('disabled') || raw.includes('deactivated')) {
            throw new Error('This account has been disabled. Please contact support.');
          } else if (raw.includes('network') || raw.includes('fetch')) {
            throw new Error('Connection error. Please check your internet and try again.');
          }
          throw new Error(r.error || 'Incorrect email or password. Please try again.');
        }
        const user = r.data?.user || r.user;
        if (!user) throw new Error('Login failed — no user returned.');
        // Role check: block students from using mentor login
        const { data: profile } = await window.supabaseConfig.client
          .from('user_profiles').select('role').eq('user_id', user.id).maybeSingle();
        const role = profile?.role || 'user';
        if (role === 'user' || role === 'student') {
          await window.supabaseConfig.client.auth.signOut();
          throw new Error('This is a Student account. Please use Student Login to sign in.');
        }
        if (role === 'admin' || role === 'super_admin') {
          await window.supabaseConfig.client.auth.signOut();
          throw new Error('Admin accounts must use the Admin Login page.');
        }
        self.currentUser = user;
        self.showLoggedInUI();
        window._pnClose();
        // Route: check mentor application record
        const { data: mentor } = await window.supabaseConfig.client
          .from('mentor_profiles').select('user_id,status').eq('user_id', user.id).maybeSingle();
        if (mentor?.status === 'approved') {
          window.location.href = self.pagesPfx + 'mentor-dashboard';
        } else if (mentor) {
          // Application pending/rejected — show friendly inline message
          window._pnOpen('mentor-login');
          const msg = mentor.status === 'rejected'
            ? 'Your mentor application was not approved. Please contact support.'
            : 'Your application is under review. You\'ll be notified by email once approved.';
          _pnErr(document.getElementById('pn-ml-err'), msg);
          btn.disabled = false; btn.textContent = 'Sign In to Portal';
        } else {
          // Mentor role exists but no application — redirect to complete the form
          window.location.href = self.pagesPfx + 'mentor-signup';
        }
      } catch(e) { _pnErr(err, e.message); btn.disabled = false; btn.textContent = 'Sign In to Portal'; }
    };

    /* ── Student Register (Supabase email verification) ── */
    window._pnStudentRegister = async () => {
      const fname  = document.getElementById('pn-ss-fname')?.value?.trim();
      const lname  = document.getElementById('pn-ss-lname')?.value?.trim();
      const email  = document.getElementById('pn-ss-email')?.value?.trim()?.toLowerCase();
      const phone  = pnNormalizePhone(document.getElementById('pn-ss-phone')?.value?.trim());
      const pw     = document.getElementById('pn-ss-pw')?.value;
      const cpw    = document.getElementById('pn-ss-cpw')?.value;
      const terms  = document.getElementById('pn-ss-terms')?.checked;
      const refRaw = (document.getElementById('pn-ss-ref')?.value?.trim() || '').toUpperCase();
      const err    = document.getElementById('pn-ss-err');
      const btn    = document.getElementById('pn-ss-btn');

      // Validate all required fields and highlight in red
      let hasErr = false;
      const setInvalid = (id, msg) => {
        const el = document.getElementById(id);
        if (el) { el.classList.add('invalid'); el.classList.remove('valid'); }
        if (!hasErr) _pnErr(err, msg);
        hasErr = true;
      };
      if (!fname || fname.length < 1) setInvalid('pn-ss-fname', 'First name is required.');
      if (!lname || lname.length < 1) setInvalid('pn-ss-lname', 'Last name is required (min 1 character).');
      if (!pnEmailRe.test(email || '')) setInvalid('pn-ss-email', 'Please enter a valid email address.');
      if (!pnPhoneRe.test(phone || '')) setInvalid('pn-ss-phone', 'Please enter a valid 10-digit Indian phone number.');
      if (!pnPasswordRe.test(pw || '')) setInvalid('pn-ss-pw', 'Password must be at least 8 characters with uppercase, lowercase, and a number.');
      if (pw !== cpw) { setInvalid('pn-ss-cpw', 'Passwords do not match.'); hasErr = true; }
      if (!terms) { _pnErr(err, 'Please agree to the Terms of Service to continue.'); hasErr = true; }

      // Block submit if referral code was entered but is invalid
      if (refRaw && _pnRefState === 'invalid') {
        _pnErr(err, 'The referral code you entered is invalid or expired. Remove it or enter a valid code.');
        hasErr = true;
      }
      // If code entered but not yet validated (state is null/pending) — validate now
      if (refRaw && _pnRefState === null) {
        _pnErr(err, 'Please wait — validating your referral code…');
        hasErr = true;
      }

      if (hasErr) return;

      btn.disabled = true; btn.textContent = 'Creating account…';
      err.style.display = 'none';

      const fullName = fname + ' ' + lname;
      const redirectTo = 'https://skillupnowadmin.org/pages/email-verified.html';

      try {
        if (!window.supabaseConfig) throw new Error('Auth service not ready. Please refresh and try again.');

        const { data, error: signUpErr } = await window.supabaseConfig.client.auth.signUp({
          email,
          password: pw,
          options: {
            data: {
              full_name: fullName, phone, role: 'user',
              ...(refRaw && _pnRefState === 'valid' ? { referral_code_used: refRaw } : {})
            },
            emailRedirectTo: redirectTo
          }
        });

        if (signUpErr) {
          const msg = signUpErr.message?.toLowerCase() || '';
          if (msg.includes('already registered') || msg.includes('already exists') || msg.includes('user already')) {
            throw new Error('An account with this email already exists. Please sign in instead.');
          }
          throw signUpErr;
        }

        const newUserId = data?.user?.id;

        // Sync profile first while session still exists (best-effort)
        if (newUserId) {
          await window.supabaseConfig.upsertUserProfile?.(newUserId, {
            full_name: fullName, email, phone, role: 'user', is_email_verified: false
          }).catch(() => {});

          // Process referral while session exists (before signOut)
          if (refRaw && _pnRefState === 'valid' && _pnRefData) {
            await window._pnProcessReferral(newUserId, _pnRefData).catch(() => {});
          }
        }

        // Sign out — prevent auto-login until email is verified
        await window.supabaseConfig.client.auth.signOut();

        // Show email verification sent screen
        document.getElementById('pn-email-sent-msg').textContent =
          'A verification link has been sent to ' + email + '. Click the link in your email to activate your account, then come back and sign in.';
        window._pnView('email-sent');

      } catch(e) {
        _pnErr(err, e.message);
        btn.disabled = false; btn.textContent = 'Create Student Account';
      }
    };

    /* ── Mentor Register (Supabase email verification → mentor signup) ── */
    window._pnMentorRegister = async () => {
      const fname     = document.getElementById('pn-sm-fname')?.value?.trim();
      const lname     = document.getElementById('pn-sm-lname')?.value?.trim();
      const email     = document.getElementById('pn-sm-email')?.value?.trim()?.toLowerCase();
      const phone     = pnNormalizePhone(document.getElementById('pn-sm-phone')?.value?.trim());
      const expertise = document.getElementById('pn-sm-expertise')?.value;
      const pw        = document.getElementById('pn-sm-pw')?.value;
      const cpw       = document.getElementById('pn-sm-cpw')?.value;
      const terms     = document.getElementById('pn-sm-terms')?.checked;
      const err       = document.getElementById('pn-sm-err');
      const btn       = document.getElementById('pn-sm-btn');

      let hasErr = false;
      const setInvalid = (id, msg) => {
        const el = document.getElementById(id);
        if (el) { el.classList.add('invalid'); el.classList.remove('valid'); }
        if (!hasErr) _pnErr(err, msg);
        hasErr = true;
      };
      if (!fname || fname.length < 1) setInvalid('pn-sm-fname', 'First name is required.');
      if (!lname || lname.length < 1) setInvalid('pn-sm-lname', 'Last name is required (min 1 character).');
      if (!pnEmailRe.test(email || '')) setInvalid('pn-sm-email', 'Please enter a valid email address.');
      if (!pnPhoneRe.test(phone || '')) setInvalid('pn-sm-phone', 'Please enter a valid 10-digit Indian phone number.');
      if (!expertise) { _pnErr(err, 'Please select your primary expertise area.'); hasErr = true; }
      if (!pnPasswordRe.test(pw || '')) setInvalid('pn-sm-pw', 'Password must be at least 8 characters with uppercase, lowercase, and a number.');
      if (pw !== cpw) { setInvalid('pn-sm-cpw', 'Passwords do not match.'); hasErr = true; }
      if (!terms) { _pnErr(err, 'Please agree to the Mentor Terms to continue.'); hasErr = true; }
      if (hasErr) return;

      btn.disabled = true; btn.textContent = 'Creating account…';
      err.style.display = 'none';

      const fullName = fname + ' ' + lname;
      const redirectTo = 'https://skillupnowadmin.org/pages/email-verified.html';

      try {
        if (!window.supabaseConfig) throw new Error('Auth service not ready. Please refresh and try again.');

        const { data, error: signUpErr } = await window.supabaseConfig.client.auth.signUp({
          email,
          password: pw,
          options: {
            data: { full_name: fullName, phone, role: 'mentor', requested_role: 'mentor', expertise_area: expertise },
            emailRedirectTo: redirectTo
          }
        });

        if (signUpErr) {
          const msg = signUpErr.message?.toLowerCase() || '';
          if (msg.includes('already registered') || msg.includes('already exists') || msg.includes('user already')) {
            throw new Error('An account with this email already exists. Please sign in instead.');
          }
          throw signUpErr;
        }

        // Sync profile first while session still exists (best-effort)
        if (data?.user?.id) {
          await window.supabaseConfig.upsertUserProfile?.(data.user.id, {
            full_name: fullName, email, phone, role: 'mentor', is_email_verified: false
          }).catch(() => {});
        }

        // Sign out — prevent auto-login until email is verified
        await window.supabaseConfig.client.auth.signOut();

        document.getElementById('pn-email-sent-msg').textContent =
          'A verification link has been sent to ' + email + '. After verifying, you\'ll be taken to the mentor application form.';
        window._pnView('email-sent');

      } catch(e) { _pnErr(err, e.message); btn.disabled = false; btn.textContent = 'Create & Continue to Application →'; }
    };

    /* ── OTP functions removed — email verification handled by Supabase ── */
    window._pnVerifyOtp = () => {}; // No-op: kept for backward compat only


    /* ── Referral code: clear state on typing ── */
    window._pnRefCodeInput = (inputId, hintId, iconId, spinId) => {
      _pnRefState = null;
      _pnRefData  = null;
      const inp  = document.getElementById(inputId);
      const hint = document.getElementById(hintId);
      const icon = document.getElementById(iconId);
      const spin = document.getElementById(spinId);
      if (inp)  { inp.classList.remove('pn-valid','pn-invalid','pn-loading'); }
      if (hint) { hint.textContent = ''; hint.className = 'pn-field-hint'; }
      if (icon) { icon.style.display = 'none'; icon.textContent = ''; }
      if (spin) { spin.style.display = 'none'; }
    };

    /* ── Referral code: async validation on blur ── */
    window._pnValidateRefCode = async (raw, inputId, hintId, iconId, spinId) => {
      const code = (raw || '').trim().toUpperCase();
      const inp  = document.getElementById(inputId);
      const hint = document.getElementById(hintId);
      const icon = document.getElementById(iconId);
      const spin = document.getElementById(spinId);

      // Clear state if blank (optional field)
      if (!code) {
        _pnRefState = null; _pnRefData = null;
        if (inp)  inp.classList.remove('pn-valid','pn-invalid','pn-loading');
        if (hint) { hint.textContent = ''; hint.className = 'pn-field-hint'; }
        if (icon) { icon.style.display = 'none'; }
        if (spin) spin.style.display = 'none';
        return;
      }

      // Show loading
      _pnRefState = null; _pnRefData = null;
      if (inp)  { inp.classList.remove('pn-valid','pn-invalid'); inp.classList.add('pn-loading'); }
      if (hint) { hint.textContent = 'Checking code…'; hint.className = 'pn-field-hint show'; }
      if (icon) icon.style.display = 'none';
      if (spin) spin.style.display = '';

      try {
        if (!window.supabaseConfig) throw new Error('service_unavailable');
        const { data, error } = await window.supabaseConfig.client
          .from('referral_codes')
          .select('id,code,description,referrer_user_id,points_for_referrer,points_for_referee,is_active,max_uses,use_count,expires_at')
          .eq('code', code)
          .maybeSingle();

        if (spin) spin.style.display = 'none';
        if (inp) inp.classList.remove('pn-loading');

        if (error || !data) {
          // Code not found
          _pnRefState = 'invalid'; _pnRefData = null;
          if (inp)  inp.classList.add('pn-invalid');
          if (icon) { icon.textContent = '✗'; icon.style.display = ''; icon.style.color = '#ef4444'; }
          if (hint) { hint.textContent = 'Invalid referral code. Please check and try again.'; hint.className = 'pn-field-hint show err'; }
          return;
        }

        // Validate: active flag
        if (!data.is_active) {
          _pnRefState = 'invalid'; _pnRefData = null;
          if (inp)  inp.classList.add('pn-invalid');
          if (icon) { icon.textContent = '✗'; icon.style.display = ''; icon.style.color = '#ef4444'; }
          if (hint) { hint.textContent = 'This referral code is no longer active.'; hint.className = 'pn-field-hint show err'; }
          return;
        }

        // Validate: expiry
        if (data.expires_at && new Date(data.expires_at) < new Date()) {
          _pnRefState = 'invalid'; _pnRefData = null;
          if (inp)  inp.classList.add('pn-invalid');
          if (icon) { icon.textContent = '✗'; icon.style.display = ''; icon.style.color = '#ef4444'; }
          if (hint) { hint.textContent = 'This referral code has expired.'; hint.className = 'pn-field-hint show err'; }
          return;
        }

        // Validate: usage limit
        if (data.max_uses !== null && data.use_count >= data.max_uses) {
          _pnRefState = 'invalid'; _pnRefData = null;
          if (inp)  inp.classList.add('pn-invalid');
          if (icon) { icon.textContent = '✗'; icon.style.display = ''; icon.style.color = '#ef4444'; }
          if (hint) { hint.textContent = 'This referral code has reached its usage limit.'; hint.className = 'pn-field-hint show err'; }
          return;
        }

        // Valid!
        _pnRefState = 'valid'; _pnRefData = data;
        if (inp)  inp.classList.add('pn-valid');
        if (icon) { icon.textContent = '✓'; icon.style.display = ''; icon.style.color = '#22c55e'; }
        const pts = data.points_for_referee || 0;
        if (hint) {
          hint.textContent = pts > 0
            ? `Code accepted! You'll earn ${pts} reward points on signup.`
            : 'Referral code accepted!';
          hint.className = 'pn-field-hint show ok';
        }

      } catch(e) {
        if (spin) spin.style.display = 'none';
        if (inp)  inp.classList.remove('pn-loading');
        // On network/service error — don't block signup, just clear
        _pnRefState = null; _pnRefData = null;
        if (hint) { hint.textContent = 'Could not verify code right now. You can still sign up.'; hint.className = 'pn-field-hint show'; }
      }
    };

    /* ── Password mismatch check (real-time) ── */
    window._pnCheckPwMatch = (pwId, cpwId, hintId) => {
      const pw  = document.getElementById(pwId)?.value  || '';
      const cpw = document.getElementById(cpwId)?.value || '';
      const el  = document.getElementById(hintId);
      if (!el) return;
      if (!cpw) { el.textContent = ''; el.className = 'pn-field-hint'; return; }
      if (pw === cpw) {
        el.textContent = 'Passwords match.';
        el.className   = 'pn-field-hint show ok';
      } else {
        el.textContent = 'Passwords do not match.';
        el.className   = 'pn-field-hint show err';
      }
    };

    /* ── Process referral after successful signUp (before signOut) ── */
    window._pnProcessReferral = async (newUserId, codeData) => {
      if (!newUserId || !codeData || !window.supabaseConfig) return;
      const client = window.supabaseConfig.client;
      const ptRef   = codeData.points_for_referee  || 0;
      const ptReferrer = codeData.points_for_referrer || 0;

      // Award points to referee (new user)
      if (ptRef > 0) {
        await client.rpc('increment_reward_points', { p_user_id: newUserId, p_points: ptRef })
          .catch(() =>
            client.from('user_profiles')
              .update({ reward_points: client.rpc('coalesce_points', {}) })
              .eq('user_id', newUserId)
              .catch(() => {})
          );
      }

      // Award points to referrer
      if (ptReferrer > 0 && codeData.referrer_user_id) {
        await client.rpc('increment_reward_points', { p_user_id: codeData.referrer_user_id, p_points: ptReferrer })
          .catch(() => {});
      }

      // Log referral event
      await client.from('referral_logs').insert({
        referrer_user_id:  codeData.referrer_user_id || null,
        referred_user_id:  newUserId,
        referral_code_used: codeData.code,
        points_to_referrer: ptReferrer,
        points_to_referee:  ptRef,
        status: 'completed'
      }).catch(() => {});

      // Increment use_count on the code
      await client.from('referral_codes')
        .update({ use_count: (codeData.use_count || 0) + 1 })
        .eq('id', codeData.id)
        .catch(() => {});
    };

    /* ── Helpers ── */
    function _pnErr(el, msg) {
      if (el) { el.textContent = msg; el.style.display = 'block'; }
    }
    function _pnClearMsg(el) {
      if (el) { el.textContent = ''; el.style.display = 'none'; }
    }
    function _pnShowSuccess(icon, title, msg, cb) {
      document.getElementById('pn-success-icon').textContent = icon;
      document.getElementById('pn-success-title').textContent = title;
      document.getElementById('pn-success-msg').textContent = msg;
      const btn = document.getElementById('pn-success-btn');
      if (cb) btn.onclick = cb;
      window._pnView('success');
      setTimeout(cb, 2200);
    }
  }

  /* ── Auth session ── */
  async checkUserSession() {
    // If supabase not ready yet, poll briefly then give up (show logged-out state)
    if (!window.supabaseConfig) {
      let tries = 0;
      await new Promise(resolve => {
        const t = setInterval(() => {
          if (window.supabaseConfig || ++tries > 15) { clearInterval(t); resolve(); }
        }, 200);
      });
    }
    try {
      if (!window.supabaseConfig) { this.showLoggedOutUI(); return; }
      const user = await window.supabaseConfig.getCurrentUser();
      if (user) { this.currentUser = user; this.showLoggedInUI(); }
      else       { this.showLoggedOutUI(); }
    } catch(e) {
      console.error('Session check error:', e);
      this.showLoggedOutUI();
    }
  }

  showLoggedInUI() {
    const ps  = document.getElementById('profile-section');
    const lw  = document.getElementById('login-wrapper');
    if (ps) { ps.style.display = 'flex'; ps.style.alignItems = 'center'; }
    if (lw)   lw.style.display = 'none';

    const btn = document.getElementById('profile-btn');
    const pdName  = document.getElementById('pd-name');
    const pdEmail = document.getElementById('pd-email');
    const pdAvatar = document.getElementById('pd-avatar-sm');
    if (btn && this.currentUser) {
      const email = this.currentUser.email || '';
      const namePart = email.split('@')[0] || 'U';
      const initial = namePart.charAt(0).toUpperCase();
      btn.textContent = initial;
      btn.title = 'Signed in as ' + email;
      if (pdEmail) pdEmail.textContent = email;

      // Load profile picture + display name
      if (window.supabaseConfig) {
        window.supabaseConfig.getUserProfile(this.currentUser.id).then(pr => {
          const pic  = pr?.data?.profile_picture_url;
          const name = pr?.data?.full_name || namePart;
          if (pdName)  pdName.textContent  = name;
          if (pdAvatar) pdAvatar.textContent = name.charAt(0).toUpperCase();
          if (pic) {
            // Avatar button
            btn.textContent = '';
            btn.style.padding = '0'; btn.style.overflow = 'hidden';
            const img = document.createElement('img');
            img.src = pic;
            img.style.cssText = 'width:100%;height:100%;border-radius:50%;object-fit:cover;display:block;';
            img.onerror = () => { btn.textContent = initial; btn.style.padding = ''; btn.style.overflow = ''; };
            btn.appendChild(img);
            // Avatar in dropdown
            if (pdAvatar) {
              pdAvatar.textContent = '';
              const img2 = document.createElement('img');
              img2.src = pic;
              img2.style.cssText = 'width:100%;height:100%;border-radius:50%;object-fit:cover;display:block;';
              img2.onerror = () => { pdAvatar.textContent = initial; };
              pdAvatar.appendChild(img2);
            }
          }
        }).catch(() => {});
      }
    }
    this.checkMentorStatus();
    this.checkAdminStatus();
    this.showStreakBadge();
  }

  showLoggedOutUI() {
    const ps = document.getElementById('profile-section');
    const lw = document.getElementById('login-wrapper');
    if (ps) ps.style.display = 'none';
    if (lw) { lw.style.display = 'flex'; lw.style.alignItems = 'center'; }
  }

  checkAdminStatus() {
    if (!window.supabaseConfig || !this.currentUser) return;
    window.supabaseConfig.checkAdminAccess(this.currentUser.id)
      .then(r => {
        if (r?.isAdmin) {
          const al = document.getElementById('dd-admin-link');
          if (al) al.style.display = 'flex';
        }
      }).catch(() => {});
  }

  checkMentorStatus() {
    if (!window.supabaseConfig || !this.currentUser) return;
    window.supabaseConfig.client
      .from('mentor_profiles').select('user_id,status').eq('user_id', this.currentUser.id).maybeSingle()
      .then(({ data }) => {
        if (data?.status === 'approved') {
          const ml = document.getElementById('dd-mentor-link');
          if (ml) ml.style.display = 'flex';
        }
      }).catch(() => {});
  }

  /* ── Public API ── */
  openLoginModal() {
    if (typeof window._pnOpen === 'function') { window._pnOpen('welcome'); return; }
    this.injectAuthModal();
    setTimeout(() => window._pnOpen?.('welcome'), 50);
  }

  openRegister() {
    if (typeof window._pnOpen === 'function') { window._pnOpen('signup-role'); return; }
    this.injectAuthModal();
    setTimeout(() => window._pnOpen?.('signup-role'), 50);
  }

  async logout() {
    // Disable any logout button that triggered this to prevent double-click
    const logoutBtns = document.querySelectorAll('.pd-logout, [onclick*="logout"]');
    logoutBtns.forEach(b => { b.style.pointerEvents = 'none'; b.style.opacity = '.5'; });

    try { if (window.supabaseConfig) await window.supabaseConfig.signOut(); } catch {}
    try { localStorage.removeItem('user_id'); localStorage.removeItem('user_email'); } catch {}
    try { sessionStorage.clear(); } catch {}
    // currentUser cleared so UI reflects logged-out state before redirect
    this.currentUser = null;
    try { this.showLoggedOutUI(); } catch {}
    // Always redirect — even if signOut threw an error
    window.location.replace(this.rootPfx || '/');
  }

  /* Backward-compat stubs */
  buildDropdown() {}
  toggleProfileDropdown() { document.getElementById('profile-dropdown')?.classList.toggle('active'); }
  setupLoginDropdown() {}
}

document.addEventListener('DOMContentLoaded', () => {
  window.profileNav = new ProfileNavigationManager();
});
