document.addEventListener('turbolinks:load', () => {
  const forms = document.querySelectorAll('.search_form');
  
  forms.forEach(form => {
    form.addEventListener('keydown', function(event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        this.submit();
      }
    });
  });
});