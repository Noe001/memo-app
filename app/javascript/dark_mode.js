// Dark Mode Toggle Implementation
// Based on: https://dev.to/ananyaneogi/create-a-dark-light-mode-switch-with-css-variables-34l8

class DarkModeToggle {
  constructor() {
    this.toggleSwitch = document.querySelector('#theme-checkbox');
    this.themeLabel = document.querySelector('.theme-label');
    this.init();
  }

  init() {
    if (!this.toggleSwitch) return;

    // Check for saved theme preference or default to system preference
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme) {
      this.setTheme(savedTheme);
    } else if (systemPrefersDark) {
      this.setTheme('dark');
    } else {
      this.setTheme('light');
    }

    // Add event listener for toggle switch
    this.toggleSwitch.addEventListener('change', (e) => {
      const theme = e.target.checked ? 'dark' : 'light';
      this.setTheme(theme);
      this.saveTheme(theme);
    });

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('theme')) {
        this.setTheme(e.matches ? 'dark' : 'light');
      }
    });
  }

  setTheme(theme) {
    const isDark = theme === 'dark';
    
    // Update document attribute
    document.documentElement.setAttribute('data-theme', theme);
    
    // Update toggle switch state
    if (this.toggleSwitch) {
      this.toggleSwitch.checked = isDark;
    }
    
    // Update theme label icons
    if (this.themeLabel) {
      const moonIcon = this.themeLabel.querySelector('.moon-icon');
      const sunIcon = this.themeLabel.querySelector('.sun-icon');
      
      if (moonIcon && sunIcon) {
        if (isDark) {
          moonIcon.style.display = 'none';
          sunIcon.style.display = 'inline-block';
        } else {
          moonIcon.style.display = 'inline-block';
          sunIcon.style.display = 'none';
        }
      } else {
        // Fallback to emoji if Lucide icons are not available
        this.themeLabel.textContent = isDark ? '☀️' : '🌙';
      }
      
      this.themeLabel.setAttribute('aria-label', isDark ? 'ライトモードに切り替え' : 'ダークモードに切り替え');
    }

    // Dispatch custom event for other components
    window.dispatchEvent(new CustomEvent('themeChanged', { 
      detail: { theme } 
    }));
  }

  saveTheme(theme) {
    localStorage.setItem('theme', theme);
  }

  getCurrentTheme() {
    return document.documentElement.getAttribute('data-theme') || 'light';
  }

  toggleTheme() {
    const currentTheme = this.getCurrentTheme();
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    this.setTheme(newTheme);
    this.saveTheme(newTheme);
  }
}

// Initialize dark mode toggle when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.darkModeToggle = new DarkModeToggle();
});

// Keyboard shortcut support (Ctrl/Cmd + Shift + D)
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
    e.preventDefault();
    if (window.darkModeToggle) {
      window.darkModeToggle.toggleTheme();
    }
  }
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = DarkModeToggle;
} 
