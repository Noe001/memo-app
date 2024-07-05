document.addEventListener("DOMContentLoaded", function() {
  const emailField = document.getElementById("email");
  const passwordField = document.getElementById("password");
  const loginButton = document.getElementById("login_button");

  function validateForm() {
    if (emailField.value !== "" && passwordField.value !== "") {
      loginButton.classList.add("active");
    } else {
      loginButton.classList.remove("active");
    }
  }

  emailField.addEventListener("input", validateForm);
  passwordField.addEventListener("input", validateForm);
});
