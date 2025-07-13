class Api::V1::SessionsController < Api::BaseController
  before_action :authenticate_v1_user!, only: [:destroy]

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
    # The token is found via authenticate_v1_user! and the user is set to @current_api_user
    # We need to find the session associated with the token to destroy it.
    token = request.headers['Authorization']&.split(' ')&.last
    session_record = Session.find_by(token: token, user: current_v1_user)

    if session_record
      session_record.destroy
      render_success(nil, :no_content)
    else
      # This case should ideally not be reached if authenticate_v1_user! is successful
      render_error('Invalid token.', :not_found)
    end
  end

  private

  def user_data(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      theme: user.theme
      # Add other relevant user data, but avoid sensitive info like password_digest
    }
  end
end
