// Dark Mode Toggle Implementation
// Based on: https://dev.to/ananyaneogi/create-a-dark-light-mode-switch-with-css-variables-34l8

// Shadcn風ダークモード切り替え機能
class ShadcnDarkModeToggle {
  constructor() {
    this.themeToggle = document.querySelector('#theme-toggle');
    this.init();
  }

  init() {
    if (!this.themeToggle) return;

    // Check for saved theme preference, server setting, or default to system preference
    const savedTheme = localStorage.getItem('theme');
    const serverTheme = document.body.getAttribute('data-theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme) {
      this.setTheme(savedTheme);
    } else if (serverTheme && serverTheme !== 'light') {
      this.setTheme(serverTheme);
    } else if (systemPrefersDark) {
      this.setTheme('dark');
    } else {
      this.setTheme('light');
    }

    // Add event listener for toggle button
    this.themeToggle.addEventListener('click', () => {
      const currentTheme = this.getCurrentTheme();
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      this.setTheme(newTheme);
      this.saveTheme(newTheme);
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
    
    // Update body attribute
    document.body.setAttribute('data-theme', theme);
    
    // Handle high-contrast theme class
    if (theme === 'high-contrast') {
      document.body.classList.add('high-contrast-theme');
    } else {
      document.body.classList.remove('high-contrast-theme');
    }
    
    // Update theme toggle icons
    this.updateIcons(isDark);

    // Dispatch custom event for other components
    window.dispatchEvent(new CustomEvent('themeChanged', { 
      detail: { theme } 
    }));
  }

  updateIcons(isDark) {
    const moonIcon = document.querySelector('.moon-icon');
    const sunIcon = document.querySelector('.sun-icon');
    
    if (moonIcon && sunIcon) {
      if (isDark) {
        moonIcon.style.display = 'none';
        sunIcon.style.display = 'inline';
      } else {
        moonIcon.style.display = 'inline';
        sunIcon.style.display = 'none';
      }
    }
    
    // Update button aria-label
    if (this.themeToggle) {
      this.themeToggle.setAttribute('aria-label', isDark ? 'ライトモードに切り替える' : 'ダークモードに切り替える');
    }
  }

  saveTheme(theme) {
    localStorage.setItem('theme', theme);
  }

  getCurrentTheme() {
    return document.body.getAttribute('data-theme') || 'light';
  }

// Update server with theme preference
  updateServerTheme(theme) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    if (!csrfToken) return;
    
    fetch('/settings', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ user: { theme: theme } })
    })
    .then(response => response.json())
    .catch(error => console.error('Error updating theme on server:', error));
  }

  toggleTheme() {
    const currentTheme = this.getCurrentTheme();
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    this.setTheme(newTheme);
    this.saveTheme(newTheme);
    this.updateServerTheme(newTheme);
  }
}

// Initialize dark mode toggle when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.shadcnDarkModeToggle = new ShadcnDarkModeToggle();
  
  // Initialize Lucide icons
  if (typeof lucide !== 'undefined') {
    lucide.createIcons();
  }
});

// Keyboard shortcut support (Ctrl/Cmd + Shift + D)
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
    e.preventDefault();
    if (window.shadcnDarkModeToggle) {
      window.shadcnDarkModeToggle.toggleTheme();
    }
  }
});


// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ShadcnDarkModeToggle;
}
