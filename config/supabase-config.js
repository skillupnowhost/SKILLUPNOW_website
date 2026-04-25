/* ==========================================
   SUPABASE CLIENT CONFIGURATION
   ========================================== */

// Import Supabase (add this to your HTML: <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>)

class SupabaseConfig {
  constructor() {
    this.SUPABASE_URL = 'https://kenlnisfhrkgolvxitfc.supabase.co';
    this.SUPABASE_ANON_KEY = 'sb_publishable_bn3ALAJLmsKePx3V-NsMBw_ADJ-3S3D';
    
    // Initialize Supabase client
    this.client = null;
    this.initializeClient();
  }

  initializeClient() {
    if (typeof supabase !== 'undefined') {
      this.client = supabase.createClient(this.SUPABASE_URL, this.SUPABASE_ANON_KEY);
      console.log('✅ Supabase client initialized successfully');
    } else {
      console.error('❌ Supabase library not loaded. Add: <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>');
    }
  }

  getClient() {
    return this.client;
  }

  normalizeRole(role) {
    const value = (role || 'user').toString().toLowerCase();
    if (value === 'student') return 'user';
    if (['user', 'mentor', 'admin', 'super_admin', 'support'].includes(value)) return value;
    return 'user';
  }

  buildProfilePayload(userId, userData = {}, overrides = {}) {
    return {
      user_id: userId,
      full_name: userData.full_name || '',
      username: userData.username || null,
      email: userData.email || '',
      phone: userData.phone || '',
      city: userData.city || null,
      state: userData.state || null,
      gender: userData.gender || null,
      role: this.normalizeRole(userData.role),
      profile_picture_url: userData.profile_picture_url || userData.avatar_url || null,
      avatar_url: userData.avatar_url || userData.profile_picture_url || null,
      address: userData.address || null,
      is_email_verified: !!userData.is_email_verified,
      updated_at: new Date().toISOString(),
      ...overrides
    };
  }

  async syncUserProfile(userId, userData = {}, overrides = {}, retryCount = 5) {
    try {
      const payload = this.buildProfilePayload(userId, userData, overrides);
      const updates = { ...payload };
      delete updates.user_id;
      delete updates.id;

      for (let attempt = 0; attempt < retryCount; attempt++) {
        const { data: existing, error: fetchError } = await this.client
          .from('user_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

        if (fetchError && fetchError.code !== 'PGRST116') throw fetchError;

        if (existing) {
          const { data, error } = await this.client
            .from('user_profiles')
            .update(updates)
            .eq('user_id', userId)
            .select()
            .maybeSingle();

          if (error) throw error;
          return { success: true, data, message: 'Profile synced successfully' };
        }

        await new Promise(resolve => setTimeout(resolve, 350));
      }

      return this.upsertUserProfile(userId, userData, overrides);
    } catch (error) {
      console.error('Error syncing profile:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== AUTHENTICATION ====================
  
  async signUp(email, password, userData = {}, options = {}) {
    try {
      const normalizedRole = this.normalizeRole(userData.role);
      const profileData = {
        ...userData,
        email,
        role: normalizedRole,
        is_email_verified: !!options.isEmailVerified
      };

      // Determine the redirect URL for email verification
      const origin = typeof window !== 'undefined' ? window.location.origin : '';
      const emailRedirectTo = origin ? origin + '/' : undefined;

      const { data, error } = await this.client.auth.signUp({
        email,
        password,
        options: {
          data: {
            ...userData,
            role: normalizedRole
          },
          emailRedirectTo
        }
      });

      if (error) throw error;

      let profileSync = { success: false, skipped: true };
      if (data.user) {
        const activeUser = data.session?.user || await this.getCurrentUser();
        if (activeUser?.id === data.user.id) {
          profileSync = await this.syncUserProfile(data.user.id, profileData);
        }
        await this.logAuditEvent(data.user.id, 'register', 'user', data.user.id);
      }

      return { success: true, data, profileSync, message: 'Account created successfully!' };
    } catch (error) {
      console.error('Sign up error:', error);
      return { success: false, error: error.message };
    }
  }

  async verifyEmailOTP(email, token, userData) {
    try {
      const { data, error } = await this.client.auth.verifyOtp({
        email,
        token,
        type: 'signup'
      });

      if (error) throw error;

      // Now create the user profile after confirmed OTP
      if (data.user) {
        await this.syncUserProfile(data.user.id, {
          ...userData,
          email,
          role: this.normalizeRole(userData?.role),
          is_email_verified: true
        });
        await this.logAuditEvent(data.user.id, 'register', 'user', data.user.id);
      }

      return { success: true, data, message: 'Email verified! Your account is ready.' };
    } catch (error) {
      console.error('OTP verification error:', error);
      return { success: false, error: error.message };
    }
  }

  async signIn(email, password) {
    try {
      const { data, error } = await this.client.auth.signInWithPassword({
        email,
        password
      });

      if (error) {
        // Provide clear, actionable error messages
        const msg = (error.message || '').toLowerCase();
        if (msg.includes('email not confirmed') || msg.includes('not confirmed')) {
          throw new Error('Please verify your email first. Check your inbox for the verification link we sent when you signed up.');
        }
        if (msg.includes('invalid login') || msg.includes('invalid credentials') || msg.includes('wrong password')) {
          throw new Error('Incorrect email or password. Please try again.');
        }
        throw error;
      }

      // Block login if email has not been verified
      if (!data.user?.email_confirmed_at) {
        await this.client.auth.signOut();
        throw new Error('Your email is not verified yet. Check your inbox for the verification link and click it before signing in.');
      }

      // Block login if the user profile was deleted (auth.users may still exist
      // briefly after deletion — this ensures they can't log in during cleanup)
      const { data: profile } = await this.client
        .from('user_profiles')
        .select('user_id')
        .eq('user_id', data.user.id)
        .maybeSingle();

      if (!profile) {
        await this.client.auth.signOut();
        throw new Error('This account no longer exists. Please register again or contact support.');
      }

      // Log the login in audit trail
      await this.logAuditEvent(data.user.id, 'login', 'user', data.user.id);

      return { success: true, data, message: 'Signed in successfully!' };
    } catch (error) {
      console.error('Sign in error:', error);
      return { success: false, error: error.message };
    }
  }

  async signOut() {
    try {
      const { error } = await this.client.auth.signOut();
      if (error) throw error;
      return { success: true, message: 'Signed out successfully!' };
    } catch (error) {
      console.error('Sign out error:', error);
      return { success: false, error: error.message };
    }
  }

  getSiteOrigin() {
    if (typeof window === 'undefined' || !window.location?.origin) return '';
    return window.location.origin.replace(/\/+$/, '');
  }

  getPasswordResetRedirectUrl() {
    const origin = this.getSiteOrigin();
    return origin ? `${origin}/pages/reset-password.html` : undefined;
  }

  async sendPasswordResetEmail(email, options = {}) {
    try {
      const redirectTo = options.redirectTo || this.getPasswordResetRedirectUrl();
      const { error } = await this.client.auth.resetPasswordForEmail(email, { redirectTo });
      if (error) throw error;
      return { success: true, redirectTo };
    } catch (error) {
      console.error('Password reset error:', error);
      const raw = (error && (error.message || error.name)) ? String(error.message || error.name) : '';
      const isFetchError =
        error instanceof TypeError ||
        /failed to fetch|networkerror|load failed/i.test(raw);

      return {
        success: false,
        error: isFetchError
          ? 'Could not reach the password reset service. Please check your internet connection and confirm the site URL is allowed in Supabase Auth Redirect URLs.'
          : raw || 'Failed to send password reset email.'
      };
    }
  }

  getJitsiMeetingUrl(sessionData = {}) {
    const clean = value => String(value || '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 24);

    const batch = clean(sessionData.batchCode || sessionData.batchName || 'batch');
    const title = clean(sessionData.title || 'class');
    const date = sessionData.startAt
      ? new Date(sessionData.startAt).toISOString().slice(0, 10).replace(/-/g, '')
      : new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const sessionNo = Number(sessionData.sessionNumber || 0);
    const suffix = clean(sessionData.sessionId || `${Date.now()}`).slice(-10);
    const room = [
      'skillupnow',
      batch,
      sessionNo ? `s${sessionNo}` : '',
      title,
      date,
      suffix
    ].filter(Boolean).join('-').slice(0, 90);

    return `https://meet.jit.si/${room}`;
  }

  async getCurrentUser() {
    try {
      const { data: { user } } = await this.client.auth.getUser();
      return user;
    } catch (error) {
      console.error('Error getting current user:', error);
      return null;
    }
  }

  async getSession() {
    try {
      const { data: { session } } = await this.client.auth.getSession();
      return session;
    } catch (error) {
      console.error('Error getting session:', error);
      return null;
    }
  }

  // ==================== USER PROFILES ====================
  
  async createUserProfile(userId, userData) {
    return this.upsertUserProfile(userId, userData);
  }

  async upsertUserProfile(userId, userData = {}, overrides = {}) {
    try {
      const { data, error } = await this.client
        .from('user_profiles')
        .upsert([this.buildProfilePayload(userId, userData, overrides)], { onConflict: 'user_id' })
        .select();

      if (error) throw error;
      return { success: true, data, message: 'Profile saved successfully' };
    } catch (error) {
      console.error('Error saving profile:', error);
      return { success: false, error: error.message };
    }
  }

  async getUserProfile(userId) {
    try {
      const { data, error } = await this.client
        .from('user_profiles')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error && error.code !== 'PGRST116') throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching profile:', error);
      return { success: false, error: error.message };
    }
  }

  async updateUserProfile(userId, updates) {
    try {
      updates.updated_at = new Date().toISOString();
      if (updates.profile_picture_url && !updates.avatar_url) updates.avatar_url = updates.profile_picture_url;
      if (updates.avatar_url && !updates.profile_picture_url) updates.profile_picture_url = updates.avatar_url;
      
      const { data, error } = await this.client
        .from('user_profiles')
        .update(updates)
        .eq('user_id', userId);

      if (error) throw error;
      return { success: true, data, message: 'Profile updated successfully' };
    } catch (error) {
      console.error('Error updating profile:', error);
      return { success: false, error: error.message };
    }
  }

  async uploadProfilePicture(userId, file) {
    try {
      const ext = file.name.split('.').pop().toLowerCase() || 'jpg';
      const path = `${userId}/avatar.${ext}`;
      const { error: uploadError } = await this.client.storage
        .from('avatars')
        .upload(path, file, { upsert: true, contentType: file.type });
      if (uploadError) throw uploadError;
      const { data: urlData } = this.client.storage
        .from('avatars')
        .getPublicUrl(path);
      const url = urlData.publicUrl + '?t=' + Date.now(); // cache-bust
      await this.updateUserProfile(userId, { profile_picture_url: url, avatar_url: url });
      return { success: true, url };
    } catch (error) {
      console.error('Error uploading profile picture:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== COURSE REGISTRATIONS ====================
  
  async enrollCourse(userId, courseData) {
    try {
      if (!courseData.pricing_id) return { success: false, error: 'No pricing ID provided.' };
      const { data, error } = await this.client
        .from('enrollments')
        .insert([{
          student_user_id: userId,
          course_id: courseData.id,
          pricing_id: courseData.pricing_id,
          enrollment_status: 'pending',
          net_amount: courseData._price || 0,
        }]);

      if (error) throw error;

      await this.logAuditEvent(userId, 'course_enroll', 'course', courseData.id);

      return { success: true, data, message: 'Course enrollment successful!' };
    } catch (error) {
      console.error('Error enrolling course:', error);
      return { success: false, error: error.message };
    }
  }

  async getEnrolledCourses(userId) {
    try {
      const { data, error } = await this.client
        .from('enrollments')
        .select('*, courses(title, thumbnail_url, duration_days)')
        .eq('student_user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching courses:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== FEEDBACK ====================
  
  async submitFeedback(feedbackData) {
    try {
      const { data, error } = await this.client
        .from('feedback')
        .insert([{
          user_id: feedbackData.user_id || null,
          full_name: feedbackData.full_name,
          email: feedbackData.email,
          phone_number: feedbackData.phone_number,
          feedback_type: feedbackData.feedback_type || 'general',
          course_id: feedbackData.course_id || null,
          course_title: feedbackData.course_title || null,
          rating: feedbackData.rating,
          subject: feedbackData.subject,
          message: feedbackData.message,
          status: 'open'
        }]);

      if (error) throw error;
      
      if (feedbackData.user_id) {
        await this.logAuditEvent(feedbackData.user_id, 'feedback_submitted', 'feedback', data[0]?.id);
      }
      
      return { success: true, data, message: 'Thank you for your feedback!' };
    } catch (error) {
      console.error('Error submitting feedback:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== EMI APPLICATIONS ====================
  
  async applyForEMI(userId, emiData) {
    try {
      const { data, error } = await this.client
        .from('emi_applications')
        .insert([{
          user_id: userId,
          full_name: emiData.full_name,
          email: emiData.email,
          phone_number: emiData.phone_number,
          course_id: emiData.course_id,
          course_title: emiData.course_title,
          course_price: emiData.course_price,
          preferred_duration: emiData.preferred_duration,
          monthly_amount: this.calculateEMIAmount(emiData.course_price, emiData.preferred_duration),
          employment_status: emiData.employment_status,
          company_name: emiData.company_name,
          annual_income: emiData.annual_income,
          id_type: emiData.id_type,
          id_number: emiData.id_number,
          application_status: 'pending'
        }]);

      if (error) throw error;
      
      await this.logAuditEvent(userId, 'emi_applied', 'emi', data[0]?.id);
      
      return { success: true, data, message: 'EMI application submitted! We will review and get back to you soon.' };
    } catch (error) {
      console.error('Error applying for EMI:', error);
      return { success: false, error: error.message };
    }
  }

  calculateEMIAmount(price, duration) {
    const months = parseInt(duration.split('_')[0]);
    return Math.round(price / months * 100) / 100;
  }

  async getEMIApplication(userId) {
    try {
      const { data, error } = await this.client
        .from('emi_applications')
        .select('*')
        .eq('user_id', userId)
        .order('applied_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching EMI applications:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== PAYMENTS ====================
  
  async recordPayment(userId, paymentData) {
    try {
      const { data, error } = await this.client
        .from('payments')
        .insert([{
          user_id: userId,
          course_id: paymentData.course_id,
          course_title: paymentData.course_title,
          amount: paymentData.amount,
          currency: paymentData.currency || 'INR',
          payment_method: paymentData.payment_method,
          transaction_id: paymentData.transaction_id,
          order_id: paymentData.order_id,
          payment_status: paymentData.payment_status || 'pending',
          payment_gateway: paymentData.payment_gateway,
          gateway_response: paymentData.gateway_response,
          emi_application_id: paymentData.emi_application_id || null,
          emi_installment_number: paymentData.emi_installment_number || null
        }]);

      if (error) throw error;
      
      if (paymentData.payment_status === 'completed') {
        await this.logAuditEvent(userId, 'payment_done', 'payment', data[0]?.id);
      }
      
      return { success: true, data, message: 'Payment recorded successfully' };
    } catch (error) {
      console.error('Error recording payment:', error);
      return { success: false, error: error.message };
    }
  }

  async getPayments(userId) {
    try {
      const { data, error } = await this.client
        .from('payments')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching payments:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== CONTACT ENQUIRIES ====================
  
  async submitContactEnquiry(enquiryData) {
    try {
      const { data, error } = await this.client
        .from('contact_enquiries')
        .insert([{
          full_name: enquiryData.full_name,
          email: enquiryData.email,
          phone_number: enquiryData.phone_number,
          course_interested: enquiryData.course_interested,
          course_title: enquiryData.course_title,
          program_duration: enquiryData.program_duration,
          learning_experience: enquiryData.learning_experience,
          current_role: enquiryData.current_role,
          company_name: enquiryData.company_name,
          budget_range: enquiryData.budget_range,
          preferred_payment_method: enquiryData.preferred_payment_method,
          preferred_contact_method: enquiryData.preferred_contact_method,
          preferred_start_date: enquiryData.preferred_start_date,
          message: enquiryData.message,
          enquiry_status: 'new'
        }]);

      if (error) throw error;
      
      return { 
        success: true, 
        data, 
        message: 'Thank you for your enquiry! Our team will contact you soon.' 
      };
    } catch (error) {
      console.error('Error submitting enquiry:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== AUDIT LOGGING ====================
  
  async logAuditEvent(userId, actionType, entityType, entityId, oldValues = null, newValues = null) {
    try {
      const { error } = await this.client
        .from('activity_logs')
        .insert([{
          actor_user_id: userId,
          actor_type: 'user',
          action_name: actionType,
          entity_type: entityType,
          entity_id: entityId ? String(entityId) : null,
          old_values: oldValues,
          new_values: newValues,
          user_agent: navigator.userAgent
        }]);

      if (error) console.error('Audit log error:', error);
    } catch (error) {
      console.error('Error logging audit event:', error);
    }
  }

  async getClientIP() {
    try {
      const response = await fetch('https://api.ipify.org?format=json');
      const data = await response.json();
      return data.ip;
    } catch {
      return 'unknown';
    }
  }

  // ==================== ADMIN FUNCTIONS ====================
  
  async checkAdminAccess(userId) {
    return this.getAdminAuthContext(userId);
  }

  async getAdminAuthContext(userId = null) {
    try {
      if (userId) {
        const [{ data: roleRow, error: roleError }, { data: accessRow, error: accessError }] = await Promise.all([
          this.client
            .from('user_role_assignments')
            .select('role, is_active')
            .eq('user_id', userId)
            .in('role', ['admin', 'super_admin', 'support'])
            .eq('is_active', true)
            .order('assigned_at', { ascending: true })
            .limit(1)
            .maybeSingle(),
          this.client
            .from('admin_profiles')
            .select('permissions, status, admin_portal_access(otp_enabled,last_login_at,portal_status,otp_verified_until)')
            .eq('user_id', userId)
            .maybeSingle()
        ]);

        if (roleError) throw roleError;
        if (accessError) throw accessError;
        if (!roleRow?.is_active || accessRow?.status !== 'active') {
          return { success: false, isAdmin: false, otp_verified: false };
        }

        const portal = accessRow?.admin_portal_access?.[0] || accessRow?.admin_portal_access || {};

        return {
          success: true,
          isAdmin: true,
          role: roleRow.role,
          permissions: accessRow?.permissions || {},
          otp_enabled: portal.otp_enabled !== false,
          otp_verified: !!portal.otp_verified_until,
          last_login_at: portal.last_login_at || null,
          portal_status: portal.portal_status || 'active'
        };
      }

      const { data, error } = await this.client.rpc('get_admin_auth_context');
      if (error) throw error;
      if (!data?.is_admin) {
        return { success: false, isAdmin: false };
      }
      return {
        success: true,
        isAdmin: !!data.is_admin,
        role: data.role,
        permissions: data.permissions || {},
        otp_enabled: data.otp_enabled !== false,
        otp_verified: !!data.otp_verified,
        last_login_at: data.last_login_at || null
      };
    } catch (error) {
      console.error('Error checking admin access:', error);
      return { success: false, isAdmin: false };
    }
  }

  async requestSignupOtp(email) {
    try {
      const { data, error } = await this.client.rpc('request_signup_email_otp', {
        p_email: email
      });
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error requesting signup OTP:', error);
      return { success: false, error: error.message };
    }
  }

  async verifySignupOtp(email, otp) {
    try {
      const { data, error } = await this.client.rpc('verify_signup_email_otp', {
        p_email: email,
        p_otp: otp
      });
      if (error) throw error;
      return { success: !!data?.verified, data, error: data?.verified ? null : data?.message };
    } catch (error) {
      console.error('Error verifying signup OTP:', error);
      return { success: false, error: error.message };
    }
  }

  async registerVerifiedUser({
    email,
    password,
    full_name,
    phone = null,
    username = null,
    role = 'user',
    metadata = {}
  } = {}) {
    try {
      const { data, error } = await this.client.rpc('register_verified_user', {
        p_email: email,
        p_password: password,
        p_full_name: full_name,
        p_phone: phone,
        p_username: username,
        p_role: role,
        p_metadata: metadata || {}
      });
      if (error) throw error;
      if (!data?.success) throw new Error(data?.message || 'Unable to create account.');
      return { success: true, data };
    } catch (error) {
      console.error('Error registering verified user:', error);
      return { success: false, error: error.message };
    }
  }

  async requestAdminLoginOtp() {
    try {
      const { data, error } = await this.client.rpc('issue_admin_login_otp');
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error requesting admin OTP:', error);
      return { success: false, error: error.message };
    }
  }

  async verifyAdminLoginOtp(otp) {
    try {
      const { data, error } = await this.client.rpc('verify_admin_login_otp', { p_otp: otp });
      if (error) throw error;
      return { success: !!data?.verified, data, error: data?.verified ? null : data?.message };
    } catch (error) {
      console.error('Error verifying admin OTP:', error);
      return { success: false, error: error.message };
    }
  }

  async setupNewAdmin(userId, inviteCode) {
    try {
      const { data, error } = await this.client.rpc('setup_new_admin', {
        p_user_id: userId,
        p_invite_code: inviteCode
      });
      if (error) throw error;
      if (!data?.success) throw new Error(data?.message || 'Failed to configure admin account.');
      return { success: true, data };
    } catch (error) {
      console.error('Error setting up admin account:', error);
      return { success: false, error: error.message };
    }
  }

  async hasAdminPermission(section, action = 'view') {
    try {
      const { data, error } = await this.client.rpc('has_admin_permission', {
        p_section: section,
        p_action: action
      });
      if (error) throw error;
      return { success: true, allowed: !!data };
    } catch (error) {
      console.error('Error checking admin permission:', error);
      return { success: false, allowed: false, error: error.message };
    }
  }

  async getAllContactEnquiries() {
    try {
      const { data, error } = await this.client
        .from('contact_enquiries')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching enquiries:', error);
      return { success: false, error: error.message };
    }
  }

  async getAllUsers() {
    try {
      const { data, error } = await this.client
        .from('user_profiles')
        .select('*')
        .order('account_created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching users:', error);
      return { success: false, error: error.message };
    }
  }

  async updateEnquiryStatus(enquiryId, status) {
    try {
      const { data, error } = await this.client
        .from('contact_enquiries')
        .update({ enquiry_status: status, updated_at: new Date().toISOString() })
        .eq('id', enquiryId);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating enquiry:', error);
      return { success: false, error: error.message };
    }
  }

  async updateEMIStatus(emiId, status, approvedBy = null) {
    try {
      const updates = {
        application_status: status,
        updated_at: new Date().toISOString()
      };
      
      if (status === 'approved') {
        updates.approved_by = approvedBy;
        updates.approval_date = new Date().toISOString();
      }

      const { data, error } = await this.client
        .from('emi_applications')
        .update(updates)
        .eq('id', emiId);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating EMI application:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== USER PROFILE FUNCTIONS ====================
  
  async getUserCourses(userId) {
    try {
      const { data, error } = await this.client
        .from('enrollments')
        .select('*, courses(title, thumbnail_url, duration_days, course_categories(name))')
        .eq('student_user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching user courses:', error);
      return [];
    }
  }

  async getUserStats(userId) {
    try {
      const { data: allCourses } = await this.client
        .from('enrollments')
        .select('id, enrollment_status, completed_at')
        .eq('student_user_id', userId);

      const completed = (allCourses || []).filter(c => c.enrollment_status === 'completed');
      const certs = (allCourses || []).filter(c => c.completed_at);

      return {
        courses_enrolled: allCourses?.length || 0,
        courses_completed: completed.length,
        certificates_earned: certs.length,
        hours_learned: completed.length * 25
      };
    } catch (error) {
      console.error('Error fetching user stats:', error);
      return { courses_enrolled: 0, courses_completed: 0, certificates_earned: 0, hours_learned: 0 };
    }
  }

  async getUserCertificates(userId) {
    try {
      const { data, error } = await this.client
        .from('enrollments')
        .select('id, completed_at, courses(title)')
        .eq('student_user_id', userId)
        .not('completed_at', 'is', null)
        .order('completed_at', { ascending: false });

      if (error) throw error;
      return (data || []).map(cert => ({
        id: cert.id,
        course_name: cert.courses?.title || 'Course',
        earned_date: cert.completed_at
      }));
    } catch (error) {
      console.error('Error fetching certificates:', error);
      return [];
    }
  }

  async getUserPayments(userId) {
    try {
      const { data, error } = await this.client
        .from('payments')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching payments:', error);
      return [];
    }
  }

  // ==================== USER ENROLLMENTS (user_enrollments table) ====================

  async createUserEnrollment(userId, enrollData) {
    try {
      const totalFee = Number(enrollData.total_fee) || 0;
      const { data, error } = await this.client
        .from('user_enrollments')
        .insert([{
          user_id: userId,
          course_id: String(enrollData.course_id),
          course_name: enrollData.course_name || '',
          course_category: enrollData.course_category || null,
          enrollment_status: 'pending',
          payment_status: 'pending',
          payment_type: 'full',
          total_fee: totalFee,
          amount_paid: 0,
          remaining_balance: totalFee,
          course_access_enabled: false
        }]);
      if (error) throw error;
      await this.logAuditEvent(userId, 'course_enroll', 'user_enrollment', data?.[0]?.id || userId);
      return { success: true, data };
    } catch (error) {
      console.error('Error creating user enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  async checkExistingEnrollment(userId, courseId) {
    try {
      const { data, error } = await this.client
        .from('user_enrollments')
        .select('id')
        .eq('user_id', userId)
        .eq('course_id', String(courseId))
        .maybeSingle();
      if (error) throw error;
      return { exists: !!data, id: data?.id };
    } catch (error) {
      console.error('Error checking enrollment:', error);
      return { exists: false };
    }
  }

  async getUserEnrollments(userId) {
    try {
      const { data, error } = await this.client
        .from('user_enrollments')
        .select('*')
        .eq('user_id', userId)
        .order('enrollment_date', { ascending: false });
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching user enrollments:', error);
      return [];
    }
  }

  async adminDeleteEnrollment(enrollmentId) {
    try {
      const { error } = await this.client
        .from('user_enrollments')
        .delete()
        .eq('id', enrollmentId);
      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error deleting enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  async adminUpdateEnrollment(enrollmentId, updates) {
    try {
      const payload = { ...updates, updated_at: new Date().toISOString() };
      // Recalculate balance if fees change
      if (payload.total_fee !== undefined || payload.amount_paid !== undefined) {
        const totalFee   = Number(payload.total_fee   ?? updates.total_fee   ?? 0);
        const amountPaid = Number(payload.amount_paid ?? updates.amount_paid ?? 0);
        payload.remaining_balance = Math.max(0, totalFee - amountPaid);
      }
      // Auto-set course_access_enabled based on enrollment_status if not explicitly set
      if (payload.enrollment_status !== undefined && payload.course_access_enabled === undefined) {
        payload.course_access_enabled = payload.enrollment_status === 'active';
      }
      const { data, error } = await this.client
        .from('user_enrollments')
        .update(payload)
        .eq('id', enrollmentId)
        .select();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  async adminCreateEnrollment(enrollData) {
    try {
      const totalFee = Number(enrollData.total_fee) || 0;
      const amountPaid = Number(enrollData.amount_paid) || 0;
      const { data, error } = await this.client
        .from('user_enrollments')
        .insert([{
          user_id: enrollData.user_id,
          course_id: String(enrollData.course_id || 'manual'),
          course_name: enrollData.course_name || '',
          course_category: enrollData.course_category || null,
          enrollment_status: enrollData.enrollment_status || 'active',
          payment_status: enrollData.payment_status || 'pending',
          payment_type: enrollData.payment_type || 'full',
          total_fee: totalFee,
          amount_paid: amountPaid,
          remaining_balance: totalFee - amountPaid,
          course_access_enabled: enrollData.enrollment_status === 'active'
        }]);
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error creating admin enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  // User-initiated cancellation: sets enrollment_status to 'cancelled', disables access
  async cancelEnrollment(enrollmentId, userId) {
    try {
      const { data, error } = await this.client
        .from('user_enrollments')
        .update({
          enrollment_status: 'cancelled',
          course_access_enabled: false,
          updated_at: new Date().toISOString()
        })
        .eq('id', enrollmentId)
        .eq('user_id', userId) // RLS safety: only own rows
        .select();
      if (error) throw error;
      await this.logAuditEvent(userId, 'course_cancel', 'user_enrollment', enrollmentId);
      return { success: true, data };
    } catch (error) {
      console.error('Error cancelling enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  async getUserEMIApplications(userId) {
    try {
      const { data, error } = await this.client
        .from('emi_applications')
        .select('*')
        .eq('user_id', userId)
        .order('applied_at', { ascending: false });
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching EMI applications:', error);
      return [];
    }
  }

  async getUserLearningPaths(userId) {
    try {
      const paths = [
        {
          id: 1,
          path_name: 'Full Stack Development',
          description: 'Master frontend and backend development',
          icon: '💻',
          progress: 45,
          total_courses: 8,
          courses_completed: 4
        },
        {
          id: 2,
          path_name: 'Data Science Mastery',
          description: 'Learn data analysis and machine learning',
          icon: '📊',
          progress: 30,
          total_courses: 6,
          courses_completed: 2
        },
        {
          id: 3,
          path_name: 'Cloud Computing',
          description: 'AWS, Azure, and GCP expertise',
          icon: '☁️',
          progress: 60,
          total_courses: 5,
          courses_completed: 3
        }
      ];
      return paths;
    } catch (error) {
      console.error('Error fetching learning paths:', error);
      return [];
    }
  }

  // ==================== USER ENROLLMENTS ====================

  async createEnrollment(userId, enrollmentData) {
    try {
      const priceRaw = enrollmentData.price || '0';
      const priceNum = typeof priceRaw === 'number'
        ? priceRaw
        : parseInt(String(priceRaw).replace(/[^\d]/g, '')) || 0;
      const { data, error } = await this.client
        .from('user_enrollments')
        .insert([{
          user_id: userId,
          course_id: enrollmentData.id,
          course_name: enrollmentData.name || enrollmentData.title || 'Course',
          course_category: enrollmentData.category || null,
          enrollment_status: 'pending',
          payment_status: enrollmentData.payment_method && enrollmentData.payment_method !== 'pending' ? 'partial' : 'pending',
          payment_type: enrollmentData.payment_type || 'full',
          payment_method: enrollmentData.payment_method || 'pending',
          total_fee: priceNum,
          amount_paid: enrollmentData.amount_paid || 0,
          remaining_balance: priceNum - (enrollmentData.amount_paid || 0),
          emi_months: enrollmentData.emi_months || null,
          emi_amount_per_month: enrollmentData.emi_amount_per_month || null,
          course_access_enabled: false
        }])
        .select()
        .single();

      if (error) throw error;
      await this.logAuditEvent(userId, 'enrollment_created', 'user_enrollment', data.id);
      return { success: true, data, message: 'Enrollment created!' };
    } catch (error) {
      console.error('Error creating enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  async getAllEnrollments() {
    try {
      const { data, error } = await this.client
        .from('user_enrollments')
        .select('*, user_profiles(full_name, email)')
        .order('enrollment_date', { ascending: false });

      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching all enrollments:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async updateEnrollmentStatus(enrollmentId, status, approvedBy = null) {
    try {
      const updates = { enrollment_status: status, updated_at: new Date().toISOString() };
      if (status === 'active') {
        updates.approved_by = approvedBy;
        updates.course_access_enabled = true;
      } else if (status === 'disabled') {
        updates.course_access_enabled = false;
      }
      const { data, error } = await this.client
        .from('user_enrollments')
        .update(updates)
        .eq('id', enrollmentId)
        .select()
        .single();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating enrollment status:', error);
      return { success: false, error: error.message };
    }
  }

  async updateEnrollmentPayment(enrollmentId, paymentData) {
    try {
      const { data, error } = await this.client
        .from('user_enrollments')
        .update({
          payment_status: paymentData.payment_status,
          payment_type: paymentData.payment_type || 'full',
          amount_paid: paymentData.amount_paid,
          remaining_balance: paymentData.remaining_balance,
          updated_at: new Date().toISOString()
        })
        .eq('id', enrollmentId)
        .select()
        .single();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating enrollment payment:', error);
      return { success: false, error: error.message };
    }
  }

  async toggleCourseAccess(enrollmentId, enabled) {
    try {
      const { data, error } = await this.client
        .from('user_enrollments')
        .update({ course_access_enabled: enabled, updated_at: new Date().toISOString() })
        .eq('id', enrollmentId)
        .select()
        .single();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error toggling course access:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== COURSE CATEGORIES ====================

  async getCategories(activeOnly = true) {
    try {
      let query = this.client
        .from('course_categories')
        .select('*')
        .order('sort_order', { ascending: true });
      if (activeOnly) query = query.eq('is_active', true);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching categories:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async createCategory(categoryData) {
    try {
      const slug = (categoryData.name || '')
        .toLowerCase().trim()
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, '-');
      const { data, error } = await this.client
        .from('course_categories')
        .insert([{
          name:                categoryData.name,
          slug:                categoryData.slug || slug,
          icon_name:           categoryData.icon_name || categoryData.icon || '📘',
          color_hex:           categoryData.color_hex || categoryData.color || '#7c5cfc',
          sort_order:          categoryData.sort_order || 99,
          created_by_admin_id: categoryData.created_by_admin_id || null,
          is_active:           true
        }])
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error creating category:', error);
      return { success: false, error: error.message };
    }
  }

  async updateCategory(categoryId, updates) {
    try {
      const normalizedUpdates = {
        ...updates,
        icon_name: updates.icon_name ?? updates.icon,
        color_hex: updates.color_hex ?? updates.color,
        updated_at: new Date().toISOString()
      };
      delete normalizedUpdates.icon;
      delete normalizedUpdates.color;
      const { data, error } = await this.client
        .from('course_categories')
        .update(normalizedUpdates)
        .eq('id', categoryId)
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating category:', error);
      return { success: false, error: error.message };
    }
  }

  async deleteCategory(categoryId) {
    try {
      const { error } = await this.client
        .from('course_categories')
        .delete()
        .eq('id', categoryId);
      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error deleting category:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== ADMIN COURSE MANAGEMENT ====================

  async getAllCourses() {
    try {
      const { data, error } = await this.client
        .from('courses')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching all courses:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async getAllCoursesAdmin() {
    try {
      const { data, error } = await this.client
        .from('courses')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching all courses (admin):', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async createCourse(courseData, adminUserId) {
    try {
      const slug = (courseData.name || courseData.title || '')
        .toLowerCase().trim()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        + '-' + Date.now();

      const { data, error } = await this.client
        .from('courses')
        .insert([{
          title: courseData.title || courseData.name || '',
          slug: courseData.slug || slug,
          category_id: courseData.category_id || courseData.category || null,
          level: (courseData.level || 'beginner').toLowerCase(),
          description: courseData.description || '',
          short_description: courseData.short_description || '',
          duration_days: courseData.duration_months ? courseData.duration_months * 30 : null,
          duration_hours: parseInt(courseData.duration_hours) || null,
          thumbnail_url: courseData.thumbnail_url || null,
          is_featured: courseData.is_featured || false,
          course_status: courseData.is_active !== false ? 'published' : 'draft',
          owner_admin_id: adminUserId,
        }])
        .select()
        .single();

      if (error) throw error;
      return { success: true, data, message: 'Course created successfully!' };
    } catch (error) {
      console.error('Error creating course:', error);
      return { success: false, error: error.message };
    }
  }

  async updateCourse(courseId, updates) {
    try {
      updates.updated_at = new Date().toISOString();
      const { data, error } = await this.client
        .from('courses')
        .update(updates)
        .eq('id', courseId)
        .select()
        .single();

      if (error) throw error;
      return { success: true, data, message: 'Course updated successfully!' };
    } catch (error) {
      console.error('Error updating course:', error);
      return { success: false, error: error.message };
    }
  }

  async deleteCourse(courseId) {
    try {
      const { error } = await this.client
        .from('courses')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('id', courseId);

      if (error) throw error;
      return { success: true, message: 'Course removed successfully!' };
    } catch (error) {
      console.error('Error deleting course:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== ADMIN STUDY MATERIALS ====================
  
  async getStudyMaterials(courseId) {
    try {
      // Mock study materials
      const materials = [
        { id: 1, course_id: courseId, title: 'Module 1: Introduction', type: 'pdf', size: '2.5MB', uploaded_at: new Date() },
        { id: 2, course_id: courseId, title: 'Module 2: Advanced Concepts', type: 'pdf', size: '3.2MB', uploaded_at: new Date() }
      ];
      return materials;
    } catch (error) {
      console.error('Error fetching study materials:', error);
      return [];
    }
  }

  async uploadStudyMaterial(courseId, materialData) {
    try {
      // Upload logic
      return { success: true, message: 'Study material uploaded successfully' };
    } catch (error) {
      console.error('Error uploading material:', error);
      return { success: false, error: error.message };
    }
  }

  async deleteStudyMaterial(materialId) {
    try {
      // Delete logic
      return { success: true, message: 'Study material deleted successfully' };
    } catch (error) {
      console.error('Error deleting material:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== ADMIN RECORDINGS ====================
  
  async getCourseRecordings(courseId) {
    try {
      // Mock recordings
      const recordings = [
        { id: 1, course_id: courseId, title: 'Live Class - Week 1', duration: '45 min', uploaded_at: new Date(), url: '#' },
        { id: 2, course_id: courseId, title: 'Live Class - Week 2', duration: '52 min', uploaded_at: new Date(), url: '#' },
        { id: 3, course_id: courseId, title: 'Q&A Session', duration: '30 min', uploaded_at: new Date(), url: '#' }
      ];
      return recordings;
    } catch (error) {
      console.error('Error fetching recordings:', error);
      return [];
    }
  }

  async uploadRecording(courseId, recordingData) {
    try {
      // Upload recording logic
      return { success: true, message: 'Recording uploaded successfully' };
    } catch (error) {
      console.error('Error uploading recording:', error);
      return { success: false, error: error.message };
    }
  }

  async deleteRecording(recordingId) {
    try {
      // Delete recording logic
      return { success: true, message: 'Recording deleted successfully' };
    } catch (error) {
      console.error('Error deleting recording:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== ADMIN DASHBOARD STATS ====================
  
  async getDashboardStats() {
    try {
      const { data: users } = await this.client
        .from('user_profiles')
        .select('id');

      const { data: enquiries } = await this.client
        .from('contact_enquiries')
        .select('id');

      const { data: emiApps } = await this.client
        .from('emi_applications')
        .select('id')
        .eq('application_status', 'pending');

      const { data: payments } = await this.client
        .from('payments')
        .select('amount')
        .eq('payment_status', 'completed');

      return {
        total_users: users?.length || 0,
        new_enquiries: enquiries?.length || 0,
        pending_emi: emiApps?.length || 0,
        total_revenue: payments?.reduce((sum, p) => sum + (p.amount || 0), 0) || 0
      };
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      return { total_users: 0, new_enquiries: 0, pending_emi: 0, total_revenue: 0 };
    }
  }

  // ==================== MENTOR MANAGEMENT ====================

  async getMentorByUserId(userId) {
    try {
      const [{ data: mentor, error: mentorError }, { data: profile, error: profileError }] = await Promise.all([
        this.client
          .from('mentor_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle(),
        this.client
          .from('user_profiles')
          .select('full_name, email, phone, profile_picture_url')
          .eq('user_id', userId)
          .maybeSingle()
      ]);
      if (mentorError) throw mentorError;
      if (profileError && profileError.code !== 'PGRST116') throw profileError;
      return { success: true, data: mentor ? { ...mentor, user_profiles: profile || null } : null };
    } catch (error) {
      console.error('Error fetching mentor:', error);
      return { success: false, error: error.message };
    }
  }

  async applyAsMentor(userId, mentorData, files = {}) {
    try {
      // Upload documents to Supabase Storage
      // Non-fatal: if the bucket doesn't exist yet, profile is still saved without URLs.
      // Admin can re-collect documents after bucket is created.
      const uploads = {};
      const bucket = 'mentor-docs';
      const uploadFile = async (key, file) => {
        if (!file) return null;
        try {
          const ext = (file.name.split('.').pop() || 'bin').toLowerCase();
          const path = `${userId}/${key}.${ext}`;
          const { error } = await this.client.storage.from(bucket).upload(path, file, { upsert: true });
          if (error) {
            console.warn(`[mentor-docs] Upload skipped for "${key}":`, error.message);
            return null;
          }
          return this.client.storage.from(bucket).getPublicUrl(path).data.publicUrl;
        } catch (uploadErr) {
          console.warn(`[mentor-docs] Upload failed for "${key}":`, uploadErr.message);
          return null;
        }
      };

      uploads.photo_url         = await uploadFile('photo', files.photo);
      uploads.pan_doc_url       = await uploadFile('pan', files.pan);
      uploads.aadhaar_doc_url   = await uploadFile('aadhaar', files.aadhaar);
      uploads.address_proof_url = await uploadFile('address_proof', files.address_proof);

      if (files.certificates?.length) {
        const certUrls = [];
        for (let i = 0; i < files.certificates.length; i++) {
          const url = await uploadFile(`cert_${i}`, files.certificates[i]);
          if (url) certUrls.push(url);
        }
        uploads.certificates_urls = certUrls;
      }

      const profileResult = await this.syncUserProfile(userId, {
        full_name: mentorData.full_name,
        username: mentorData.username,
        email: mentorData.email,
        phone: mentorData.phone,
        role: 'mentor',
        is_email_verified: true
      });
      if (!profileResult.success) throw new Error(profileResult.error || 'Failed to save mentor profile');

      const { data, error } = await this.client
        .from('mentor_profiles')
        .upsert({
          user_id:            userId,
          designation:        mentorData.designation || null,
          qualifications:     mentorData.qualifications || '',
          expertise_areas:    mentorData.expertise_areas || [],
          years_of_experience: parseInt(mentorData.years_experience) || 0,
          bio:                mentorData.bio || null,
          linkedin_url:       mentorData.linkedin_url || null,
          pan_number:         mentorData.pan_number || null,
          aadhaar_number:     mentorData.aadhaar_number || null,
          salary_type:        mentorData.salary_type || 'per_session',
          photo_url:          uploads.photo_url || null,
          status:             'pending',
        }, { onConflict: 'user_id' })
        .select()
        .single();

      if (error) throw error;

      const documentRows = [];
      if (uploads.photo_url) {
        documentRows.push({
          mentor_user_id: userId,
          document_type: 'profile_photo',
          file_name: files.photo?.name || 'photo',
          storage_bucket: bucket,
          storage_path: `${userId}/photo.${files.photo?.name?.split('.').pop() || 'jpg'}`,
          public_url: uploads.photo_url
        });
      }
      if (uploads.pan_doc_url) {
        documentRows.push({
          mentor_user_id: userId,
          document_type: 'id_proof',
          file_name: files.pan?.name || 'pan',
          storage_bucket: bucket,
          storage_path: `${userId}/pan.${files.pan?.name?.split('.').pop() || 'pdf'}`,
          public_url: uploads.pan_doc_url
        });
      }
      if (uploads.aadhaar_doc_url) {
        documentRows.push({
          mentor_user_id: userId,
          document_type: 'id_proof',
          file_name: files.aadhaar?.name || 'aadhaar',
          storage_bucket: bucket,
          storage_path: `${userId}/aadhaar.${files.aadhaar?.name?.split('.').pop() || 'pdf'}`,
          public_url: uploads.aadhaar_doc_url
        });
      }
      if (uploads.address_proof_url) {
        documentRows.push({
          mentor_user_id: userId,
          document_type: 'other',
          file_name: files.address_proof?.name || 'address_proof',
          storage_bucket: bucket,
          storage_path: `${userId}/address_proof.${files.address_proof?.name?.split('.').pop() || 'pdf'}`,
          public_url: uploads.address_proof_url
        });
      }
      (uploads.certificates_urls || []).forEach((url, index) => {
        documentRows.push({
          mentor_user_id: userId,
          document_type: 'certification',
          file_name: files.certificates?.[index]?.name || `certificate_${index + 1}`,
          storage_bucket: bucket,
          storage_path: `${userId}/cert_${index}.${files.certificates?.[index]?.name?.split('.').pop() || 'pdf'}`,
          public_url: url
        });
      });

      if (documentRows.length) {
        await this.client.from('mentor_documents').insert(documentRows);
      }

      // Log form submission
      await this.saveFormSubmission(userId, 'mentor_signup', null, {
        ...mentorData,
        mentor_user_id: data.user_id,
        uploaded_documents: documentRows.map(row => ({
          document_type: row.document_type,
          file_name: row.file_name,
          public_url: row.public_url
        })),
      });

      await this.logAuditEvent(userId, 'mentor_applied', 'mentor', data.user_id);
      return { success: true, data, message: 'Application submitted! Awaiting admin approval.' };
    } catch (error) {
      console.error('Error applying as mentor:', error);
      return { success: false, error: error.message };
    }
  }

  async getAllMentors(statusFilter = null) {
    try {
      let query = this.client
        .from('mentor_profiles')
        .select('*')
        .order('created_at', { ascending: false });
      if (statusFilter) query = query.eq('status', statusFilter);
      const { data, error } = await query;
      if (error) throw error;

      const userIds = [...new Set((data || []).map(item => item.user_id).filter(Boolean))];
      let profileMap = {};
      if (userIds.length) {
        const { data: profiles, error: profileError } = await this.client
          .from('user_profiles')
          .select('user_id, full_name, email, phone, profile_picture_url')
          .in('user_id', userIds);
        if (profileError) throw profileError;
        profileMap = Object.fromEntries((profiles || []).map(profile => [profile.user_id, profile]));
      }

      return {
        success: true,
        data: (data || []).map(item => ({ ...item, user_profiles: profileMap[item.user_id] || null }))
      };
    } catch (error) {
      console.error('Error fetching mentors:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async approveMentor(mentorId, status, adminUserId, notes = null) {
    try {
      const updates = {
        status,
        approved_by_admin_id: status === 'approved' ? adminUserId : null,
        approved_at: status === 'approved' ? new Date().toISOString() : null,
        rejection_reason: status === 'rejected' ? (notes || null) : null,
        updated_at: new Date().toISOString(),
      };
      const { data, error } = await this.client
        .from('mentor_profiles')
        .update(updates)
        .eq('user_id', mentorId)
        .select()
        .single();
      if (error) throw error;
      await this.logAuditEvent(adminUserId, `mentor_${status}`, 'mentor', mentorId);
      return { success: true, data, message: `Mentor ${status} successfully.` };
    } catch (error) {
      console.error('Error approving mentor:', error);
      return { success: false, error: error.message };
    }
  }

  async updateMentorSalary(mentorId, salaryData, adminUserId) {
    try {
      const { data, error } = await this.client
        .from('mentor_profiles')
        .update({
          salary_amount: parseFloat(salaryData.salary_per_month) || 0,
          salary_type: salaryData.salary_type || 'fixed_monthly',
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', mentorId)
        .select()
        .single();
      if (error) throw error;
      await this.logAuditEvent(adminUserId, 'mentor_salary_updated', 'mentor', mentorId);
      return { success: true, data };
    } catch (error) {
      console.error('Error updating mentor salary:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== MENTOR BATCHES ====================

  async getMentorBatches(mentorId) {
    try {
      const { data, error } = await this.client
        .from('course_batches')
        .select('*, courses(title, duration_days)')
        .eq('primary_mentor_user_id', mentorId)
        .order('starts_on', { ascending: false });
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching mentor batches:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async createBatch(batchData, adminUserId) {
    try {
      const { data, error } = await this.client
        .from('course_batches')
        .insert([{
          course_id:               batchData.course_id,
          primary_mentor_user_id:  batchData.mentor_id || null,
          batch_name:              batchData.batch_name || `Batch ${Date.now()}`,
          batch_code:              batchData.batch_code || `B${Date.now()}`,
          starts_on:               batchData.start_date || null,
          ends_on:                 batchData.end_date || null,
          max_students:            parseInt(batchData.max_students) || 30,
          schedule_json:           batchData.schedule_info ? { info: batchData.schedule_info } : {},
          is_active:               true,
        }])
        .select()
        .single();
      if (error) throw error;
      await this.logAuditEvent(adminUserId, 'batch_created', 'mentor_batch', data.id);
      return { success: true, data };
    } catch (error) {
      console.error('Error creating batch:', error);
      return { success: false, error: error.message };
    }
  }

  async updateBatch(batchId, updates, adminUserId) {
    try {
      updates.updated_at = new Date().toISOString();
      const { data, error } = await this.client
        .from('course_batches')
        .update(updates)
        .eq('id', batchId)
        .select()
        .single();
      if (error) throw error;
      await this.logAuditEvent(adminUserId, 'batch_updated', 'mentor_batch', batchId);
      return { success: true, data };
    } catch (error) {
      console.error('Error updating batch:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== CLASS SCHEDULES ====================

  async getClassSchedules(batchId = null, mentorId = null, userId = null) {
    try {
      let query = this.client
        .from('class_sessions')
        .select('*, course_batches:batch_id(batch_name, courses(title)), mentor_profiles:mentor_user_id(user_profiles(full_name))')
        .order('scheduled_start_at', { ascending: true });
      if (batchId)   query = query.eq('batch_id', batchId);
      if (mentorId)  query = query.eq('mentor_user_id', mentorId);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching schedules:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async createSchedule(scheduleData) {
    try {
      // Calculate end time from duration
      const startAt = new Date(scheduleData.scheduled_at);
      const durationMins = parseInt(scheduleData.duration_minutes) || 60;
      const endAt = new Date(startAt.getTime() + durationMins * 60000);
      const { data, error } = await this.client
        .from('class_sessions')
        .insert([{
          batch_id:            scheduleData.batch_id,
          course_id:           scheduleData.course_id,
          mentor_user_id:      scheduleData.mentor_id,
          session_title:       scheduleData.title || 'Live Class',
          scheduled_start_at:  scheduleData.scheduled_at,
          scheduled_end_at:    endAt.toISOString(),
          meeting_url:         scheduleData.meet_link || null,
          session_status:      'scheduled',
        }])
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error creating schedule:', error);
      return { success: false, error: error.message };
    }
  }

  async updateSchedule(scheduleId, updates) {
    try {
      updates.updated_at = new Date().toISOString();
      const { data, error } = await this.client
        .from('class_sessions')
        .update(updates)
        .eq('id', scheduleId)
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating schedule:', error);
      return { success: false, error: error.message };
    }
  }

  async markAttendance(scheduleId, userId, status = 'present') {
    try {
      const { data, error } = await this.client
        .from('class_attendance')
        .upsert({ class_session_id: scheduleId, student_user_id: userId, status }, { onConflict: 'class_session_id,student_user_id' })
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error marking attendance:', error);
      return { success: false, error: error.message };
    }
  }

  async getAttendanceForClass(scheduleId) {
    try {
      const { data, error } = await this.client
        .from('class_attendance')
        .select('*, user_profiles(full_name, email, profile_picture_url)')
        .eq('schedule_id', scheduleId);
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching attendance:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  // ==================== FORM SUBMISSIONS ====================

  async saveFormSubmission(userId, formType, courseId, formData) {
    try {
      const { data, error } = await this.client
        .from('form_submissions')
        .insert([{
          user_id:   userId || null,
          form_type: formType,
          course_id: courseId || null,
          form_data: formData || {},
          status:    'received',
        }])
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error saving form submission:', error);
      return { success: false, error: error.message };
    }
  }

  async getFormSubmissions(formType = null, limit = 100) {
    try {
      let query = this.client
        .from('form_submissions')
        .select('*, user_profiles(full_name, email)')
        .order('submitted_at', { ascending: false })
        .limit(limit);
      if (formType) query = query.eq('form_type', formType);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching form submissions:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async updateFormSubmissionStatus(submissionId, status, adminNotes = null) {
    try {
      const { data, error } = await this.client
        .from('form_submissions')
        .update({ status, admin_notes: adminNotes, updated_at: new Date().toISOString() })
        .eq('id', submissionId)
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating form submission:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== REVIEWS ====================

  async getReviews(courseId = null, approvedOnly = false, limit = 50) {
    try {
      let query = this.client
        .from('reviews')
        .select('*, user_profiles(full_name, profile_picture_url), courses(title)')
        .order('created_at', { ascending: false })
        .limit(limit);
      if (courseId)    query = query.eq('course_id', courseId);
      if (approvedOnly) query = query.eq('is_approved', true);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching reviews:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async approveReview(reviewId, adminUserId) {
    try {
      const { data, error } = await this.client
        .from('reviews')
        .update({ is_approved: true, updated_at: new Date().toISOString() })
        .eq('id', reviewId)
        .select()
        .single();
      if (error) throw error;
      await this.logAuditEvent(adminUserId, 'review_approved', 'review', reviewId);
      return { success: true, data };
    } catch (error) {
      console.error('Error approving review:', error);
      return { success: false, error: error.message };
    }
  }

  async deleteReview(reviewId, adminUserId) {
    try {
      const { error } = await this.client.from('reviews').delete().eq('id', reviewId);
      if (error) throw error;
      await this.logAuditEvent(adminUserId, 'review_deleted', 'review', reviewId);
      return { success: true };
    } catch (error) {
      console.error('Error deleting review:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== INQUIRIES ====================

  async getInquiries(statusFilter = null, limit = 100) {
    try {
      let query = this.client
        .from('inquiries')
        .select('*, courses(title)')
        .order('created_at', { ascending: false })
        .limit(limit);
      if (statusFilter) query = query.eq('status', statusFilter);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching inquiries:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async updateInquiryStatus(inquiryId, status, adminNotes = null) {
    try {
      const { data, error } = await this.client
        .from('inquiries')
        .update({ status, admin_notes: adminNotes, updated_at: new Date().toISOString() })
        .eq('id', inquiryId)
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error updating inquiry:', error);
      return { success: false, error: error.message };
    }
  }

  // ==================== REPORTS & ANALYTICS ====================

  async getAdminDashboardView() {
    try {
      const { data, error } = await this.client
        .from('v_admin_dashboard')
        .select('*')
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching admin dashboard view:', error);
      return { success: false, error: error.message };
    }
  }

  async getRevenueByCourse() {
    try {
      const { data, error } = await this.client
        .from('v_revenue_by_course')
        .select('*')
        .order('total_revenue', { ascending: false })
        .limit(20);
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching revenue by course:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async getRevenueByMonth() {
    try {
      const { data, error } = await this.client
        .from('v_revenue_by_month')
        .select('*')
        .order('month', { ascending: false })
        .limit(12);
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching revenue by month:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async getMentorPerformance() {
    try {
      const { data, error } = await this.client
        .from('v_mentor_performance')
        .select('*')
        .order('avg_rating', { ascending: false });
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching mentor performance:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async getUserEnrollmentSummary(userId = null) {
    try {
      let query = this.client.from('v_user_enrollment_summary').select('*');
      if (userId) query = query.eq('user_id', userId);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: userId ? (data?.[0] || null) : (data || []) };
    } catch (error) {
      console.error('Error fetching user enrollment summary:', error);
      return { success: false, error: error.message };
    }
  }

  async getPaymentReport(startDate = null, endDate = null) {
    try {
      let query = this.client
        .from('payments')
        .select('*, user_profiles(full_name, email), courses(title)')
        .eq('payment_status', 'completed')
        .order('payment_date', { ascending: false });
      if (startDate) query = query.gte('payment_date', startDate);
      if (endDate)   query = query.lte('payment_date', endDate);
      const { data, error } = await query;
      if (error) throw error;

      const total = (data || []).reduce((sum, p) => sum + parseFloat(p.amount || 0), 0);
      return { success: true, data: data || [], total };
    } catch (error) {
      console.error('Error fetching payment report:', error);
      return { success: false, data: [], total: 0, error: error.message };
    }
  }

  async getEmiReport(statusFilter = null) {
    try {
      let query = this.client
        .from('emi_schedules')
        .select('*, enrollments(user_id, course_id, user_profiles(full_name, email), courses(title))')
        .order('due_date', { ascending: true });
      if (statusFilter) query = query.eq('status', statusFilter);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching EMI report:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async getStudentReport() {
    try {
      const { data, error } = await this.client
        .from('user_profiles')
        .select('id, full_name, email, phone, role, account_created_at, last_login_at, enrollments(count)')
        .eq('role', 'student')
        .order('account_created_at', { ascending: false });
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching student report:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  // ==================== NOTIFICATIONS ====================

  async sendNotification(userId, title, message, type = 'info', link = null) {
    try {
      const { data, error } = await this.client
        .from('notifications')
        .insert([{ user_id: userId, title, message, type, link }])
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error sending notification:', error);
      return { success: false, error: error.message };
    }
  }

  async getUserNotifications(userId, unreadOnly = false) {
    try {
      let query = this.client
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50);
      if (unreadOnly) query = query.eq('is_read', false);
      const { data, error } = await query;
      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('Error fetching notifications:', error);
      return { success: false, data: [], error: error.message };
    }
  }

  async markNotificationRead(notificationId) {
    try {
      const { data, error } = await this.client
        .from('notifications')
        .update({ is_read: true, read_at: new Date().toISOString() })
        .eq('id', notificationId)
        .select()
        .single();
      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error marking notification read:', error);
      return { success: false, error: error.message };
    }
  }
}

// Initialize and export
const supabaseConfig = new SupabaseConfig();

// Make it globally available
window.supabaseConfig = supabaseConfig;
// Expose the raw Supabase client so admin dashboard can call .from() directly
window.supabaseConfig.supabase = supabaseConfig.client;
window.supabase = typeof supabase !== 'undefined' ? supabase : null;
