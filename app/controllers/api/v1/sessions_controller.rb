class Api::V1::SessionsController < Api::V1::BaseController
  # No authentication needed for creating a session (login)
  # before_action :authenticate_api_user!, only: [:destroy] # Authenticate for logout

  def create
    user = User.find_by(email: params[:email]&.downcase)

    if user&.authenticate(params[:password])
      # Create a new session record using the Session model
      # The Session model's before_create :generate_token will create the token
      session_record = user.sessions.build(
        user_agent: request.user_agent,
        ip_address: request.remote_ip
        # expires_at will be set by the Session model's generate_token
      )

      if session_record.save
        render_success({ token: session_record.token, expires_at: session_record.expires_at, user: user_data(user) }, :created)
      else
        # This case should be rare if user.sessions.build and save are used correctly
        # and Session model validations pass (e.g. token generation always works)
        render_error("Failed to create session: #{session_record.errors.full_messages.join(', ')}", :internal_server_error)
      end
    else
      render_error('Invalid email or password.', :unauthorized)
    end
  end

  def destroy
    token = request.headers['Authorization']&.split(' ')&.last
    if token.blank?
      return render_error('Missing token.', :unauthorized)
    end

    session_record = Session.find_by(token: token)

    if session_record
      # We might also want to check if session_record.user == current_api_user if authenticate_api_user! was implemented and used
      session_record.destroy
      render_success(nil, :no_content) # Successfully logged out
    else
      render_error('Invalid token or session already terminated.', :not_found)
    end
  end

  private

  def user_data(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      theme: user.theme,
      font_size: user.font_size
      # Add other relevant user data, but avoid sensitive info like password_digest
    }
  end
end
