history.replaceState('', '', '/signup');

document.addEventListener("DOMContentLoaded", function() {
  const nameField = document.getElementById("name")
  const emailField = document.getElementById("email");
  const passwordField = document.getElementById("password");
  const passwordConfirmationField = document.getElementById("password_confirmation")
  const createButtonField = document.getElementById("create_button");

  function validateForm() {
    if (
      nameField.value !== "" &&
      emailField.value !== "" &&
      passwordField.value !== "" &&
      passwordConfirmationField.value !== ""
    ) {
      createButtonField.classList.add("active");
    } else {
      createButtonField.classList.remove("active");
    }
  }

  nameField.addEventListener("input", validateForm);
  emailField.addEventListener("input", validateForm);
  passwordField.addEventListener("input", validateForm);
  passwordConfirmationField.addEventListener("input", validateForm);
});