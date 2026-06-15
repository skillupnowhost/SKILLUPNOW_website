/* ==========================================
   THEME MANAGEMENT (Light/Dark Mode)
   ========================================== */

class ThemeManager {
  constructor() {
    // Sync with pn-theme (new switcher) or fall back to old 'theme' key, default light
    this.currentTheme = localStorage.getItem('pn-theme') || localStorage.getItem('theme') || 'light';
    this.root = document.documentElement;
    this.toggleButton = null;
    this.init();
  }

  init() {
    // Apply saved variant
    const variant = localStorage.getItem('pn-theme-variant');
    if (variant && variant !== 'purple') this.root.setAttribute('data-theme-variant', variant);
    // Set initial theme
    this.setTheme(this.currentTheme);
    
    // Setup theme toggle button if it exists
    this.toggleButton = document.querySelector('.theme-toggle');
    if (this.toggleButton) {
      this.toggleButton.addEventListener('click', () => this.toggleTheme());
    }

    // Listen for system theme changes
    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
        if (!localStorage.getItem('theme')) {
          this.setTheme(e.matches ? 'dark' : 'light');
        }
      });
    }
  }

  setTheme(theme) {
    this.currentTheme = theme;
    this.root.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
    localStorage.setItem('pn-theme', theme); // Keep in sync with switcher
    this.updateToggleButtonUI();
    this.updateMetaThemeColor();
    this.dispatchThemeChangeEvent();
  }

  toggleTheme() {
    const newTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
    this.setTheme(newTheme);
  }

  updateToggleButtonUI() {
    if (this.toggleButton) {
      if (this.currentTheme === 'light') {
        this.toggleButton.classList.add('light');
        this.toggleButton.setAttribute('aria-pressed', 'true');
      } else {
        this.toggleButton.classList.remove('light');
        this.toggleButton.setAttribute('aria-pressed', 'false');
      }
    }
    // Update icon-only theme buttons
    document.querySelectorAll('.theme-icon-btn').forEach(btn => {
      btn.textContent = this.currentTheme === 'dark' ? '☀️' : '🌙';
    });
  }

  updateMetaThemeColor() {
    let metaThemeColor = document.querySelector('meta[name="theme-color"]');
    
    if (!metaThemeColor) {
      metaThemeColor = document.createElement('meta');
      metaThemeColor.name = 'theme-color';
      document.head.appendChild(metaThemeColor);
    }

    if (this.currentTheme === 'light') {
      metaThemeColor.content = '#42A5F5';
    } else {
      metaThemeColor.content = '#64B5F6';
    }
  }

  dispatchThemeChangeEvent() {
    window.dispatchEvent(new CustomEvent('themechange', {
      detail: { theme: this.currentTheme }
    }));
  }

  getTheme() {
    return this.currentTheme;
  }

  isDarkMode() {
    return this.currentTheme === 'dark';
  }

  isLightMode() {
    return this.currentTheme === 'light';
  }

  getSystemTheme() {
    if (window.matchMedia) {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return 'dark';
  }
}

// Initialize theme manager on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  window.themeManager = new ThemeManager();
});

// Utility function to get current theme
function getCurrentTheme() {
  return document.documentElement.getAttribute('data-theme') || 'dark';
}

// Utility function to toggle theme
function toggleTheme() {
  if (window.themeManager) {
    window.themeManager.toggleTheme();
  }
}

// Utility function to set specific theme
function setTheme(theme) {
  if (window.themeManager) {
    window.themeManager.setTheme(theme);
  }
}

// Listen for theme changes
document.addEventListener('themechange', (event) => {
  const theme = event.detail.theme;
  console.log('Theme changed to:', theme);
  
  // Update any dynamic elements that depend on theme
  updateThemeDependentElements(theme);
});

function updateThemeDependentElements(theme) {
  // Update chart colors if using charting library
  if (window.chart) {
    window.chart.update();
  }

  // Update canvas elements
  const canvases = document.querySelectorAll('canvas');
  canvases.forEach(canvas => {
    canvas.dispatchEvent(new Event('themechange'));
  });

  // Trigger any custom theme update logic
  const themeEvent = new CustomEvent('updateTheme', { detail: { theme } });
  document.dispatchEvent(themeEvent);
}

// CSS variable helper for theme-based colors
const ThemeColors = {
  getColorVariable: (variableName) => {
    return getComputedStyle(document.documentElement).getPropertyValue(variableName).trim();
  },

  getPrimaryColor: () => ThemeColors.getColorVariable('--v1'),
  
  getSecondaryColor: () => ThemeColors.getColorVariable('--v2'),
  
  getBackgroundColor: () => ThemeColors.getColorVariable('--bg'),
  
  getTextColor: () => ThemeColors.getColorVariable('--txt'),
  
  getGradient: () => {
    const isDark = getCurrentTheme() === 'dark';
    return isDark 
      ? 'linear-gradient(135deg, #7c5cfc 0%, #3d6bff 100%)'
      : 'linear-gradient(135deg, #7c5cfc 0%, #3d6bff 100%)';
  },

  getShadow: () => ThemeColors.getColorVariable('--shadow-card'),
  
  getAllColors: () => {
    const root = document.documentElement;
    const style = getComputedStyle(root);
    const colors = {};
    
    const colorVars = [
      '--bg', '--bg2', '--txt', '--txt2', '--txt3', '--txt4',
      '--v1', '--v2', '--v3', '--v4', '--v5',
      '--b1', '--b2', '--b3'
    ];
    
    colorVars.forEach(varName => {
      colors[varName.substring(2)] = style.getPropertyValue(varName).trim();
    });
    
    return colors;
  }
};

// Theme persistence with multiple storage options
class ThemePersistence {
  static save(theme) {
    try {
      localStorage.setItem('app-theme', theme);
      sessionStorage.setItem('app-theme-session', theme);
    } catch (e) {
      console.warn('Could not save theme to storage:', e);
    }
  }

  static load() {
    try {
      return localStorage.getItem('app-theme') || sessionStorage.getItem('app-theme-session') || 'dark';
    } catch (e) {
      console.warn('Could not load theme from storage:', e);
      return 'dark';
    }
  }

  static clear() {
    try {
      localStorage.removeItem('app-theme');
      sessionStorage.removeItem('app-theme-session');
    } catch (e) {
      console.warn('Could not clear theme from storage:', e);
    }
  }
}

// Auto-detect theme based on time of day (optional)
class TimeBasedTheme {
  static getTimeBasedTheme() {
    const hour = new Date().getHours();
    // Light mode from 6 AM to 6 PM
    return (hour >= 6 && hour < 18) ? 'light' : 'dark';
  }

  static enable() {
    const theme = this.getTimeBasedTheme();
    if (window.themeManager) {
      window.themeManager.setTheme(theme);
    }
  }

  static disable() {
    // Fall back to user preference
    if (window.themeManager) {
      window.themeManager.setTheme(localStorage.getItem('theme') || 'dark');
    }
  }
}

// Keyboard shortcut for theme toggle (Alt + T)
document.addEventListener('keydown', (event) => {
  if (event.altKey && event.key === 't') {
    event.preventDefault();
    toggleTheme();
  }
});

// Export for use
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ThemeManager, ThemeColors, ThemePersistence, TimeBasedTheme };
}
