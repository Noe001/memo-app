// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "./dark_mode"

// Initialize Lucide icons
document.addEventListener('DOMContentLoaded', function() {
  if (typeof lucide !== 'undefined') {
    lucide.createIcons();
  }
});

// Re-initialize icons after Turbo navigation
document.addEventListener('turbo:load', function() {
  if (typeof lucide !== 'undefined') {
    lucide.createIcons();
  }
});
