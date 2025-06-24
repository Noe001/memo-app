// Dark Mode Toggle Implementation
// Based on: https://dev.to/ananyaneogi/create-a-dark-light-mode-switch-with-css-variables-34l8

// Shadcn風テーマ切り替え機能（3つのテーマ対応）
class ShadcnThemeToggle {
  constructor() {
    this.themeToggle = document.querySelector('#theme-toggle');
    this.themes = ['light', 'dark', 'high-contrast'];
    this.init();
  }

  init() {
    if (!this.themeToggle) return;

    // Check for saved theme preference, server setting, or default to system preference
    const savedTheme = localStorage.getItem('theme');
    const serverTheme = document.body.getAttribute('data-theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme && this.themes.includes(savedTheme)) {
      this.setTheme(savedTheme);
    } else if (serverTheme && this.themes.includes(serverTheme)) {
      this.setTheme(serverTheme);
    } else if (systemPrefersDark) {
      this.setTheme('dark');
    } else {
      this.setTheme('light');
    }

    // Add event listener for toggle button (cycles through themes)
    this.themeToggle.addEventListener('click', () => {
      const currentTheme = this.getCurrentTheme();
      const newTheme = this.getNextTheme(currentTheme);
      this.setTheme(newTheme);
      this.saveTheme(newTheme);
      this.updateServerTheme(newTheme);
    });

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('theme')) {
        this.setTheme(e.matches ? 'dark' : 'light');
      }
    });
  }

  getNextTheme(currentTheme) {
    const currentIndex = this.themes.indexOf(currentTheme);
    const nextIndex = (currentIndex + 1) % this.themes.length;
    return this.themes[nextIndex];
  }

  setTheme(theme) {
    if (!this.themes.includes(theme)) {
      theme = 'light'; // fallback to light theme
    }
    
    // Update body attribute
    document.body.setAttribute('data-theme', theme);
    
    // Remove any legacy theme classes (no longer needed)
    document.body.classList.remove('high-contrast-theme');
    
    // Update theme toggle icons
    this.updateIcons(theme);

    // Dispatch custom event for other components
    window.dispatchEvent(new CustomEvent('themeChanged', { 
      detail: { theme } 
    }));
  }

  updateIcons(theme) {
    const moonIcon = document.querySelector('.moon-icon');
    const sunIcon = document.querySelector('.sun-icon');
    const contrastIcon = document.querySelector('.contrast-icon');
    
    // Hide all icons first
    if (moonIcon) moonIcon.style.display = 'none';
    if (sunIcon) sunIcon.style.display = 'none';
    if (contrastIcon) contrastIcon.style.display = 'none';
    
    // Show appropriate icon based on theme
    switch (theme) {
      case 'light':
        if (moonIcon) moonIcon.style.display = 'inline';
        break;
      case 'dark':
        if (contrastIcon) {
          contrastIcon.style.display = 'inline';
        } else if (sunIcon) {
          sunIcon.style.display = 'inline';
        }
        break;
      case 'high-contrast':
        if (sunIcon) sunIcon.style.display = 'inline';
        break;
    }
    
    // Update button aria-label
    if (this.themeToggle) {
      const labels = {
        'light': 'ダークモードに切り替える',
        'dark': '高コントラストモードに切り替える',
        'high-contrast': 'ライトモードに切り替える'
      };
      this.themeToggle.setAttribute('aria-label', labels[theme] || 'テーマを切り替える');
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
    const newTheme = this.getNextTheme(currentTheme);
    this.setTheme(newTheme);
    this.saveTheme(newTheme);
    this.updateServerTheme(newTheme);
  }

  // Direct theme setting methods for external use
  setLightTheme() {
    this.setTheme('light');
    this.saveTheme('light');
    this.updateServerTheme('light');
  }

  setDarkTheme() {
    this.setTheme('dark');
    this.saveTheme('dark');
    this.updateServerTheme('dark');
  }

  setHighContrastTheme() {
    this.setTheme('high-contrast');
    this.saveTheme('high-contrast');
    this.updateServerTheme('high-contrast');
  }
}

// Initialize theme toggle when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.shadcnThemeToggle = new ShadcnThemeToggle();
  
  // Initialize Lucide icons
  if (typeof lucide !== 'undefined') {
    lucide.createIcons();
  }
});

// Keyboard shortcut support (Ctrl/Cmd + Shift + D)
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
    e.preventDefault();
    if (window.shadcnThemeToggle) {
      window.shadcnThemeToggle.toggleTheme();
    }
  }
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ShadcnThemeToggle;
}
