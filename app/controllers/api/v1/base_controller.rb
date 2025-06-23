class Api::V1::BaseController < ApplicationController
  # Disable CSRF protection for API requests, as token auth will be used.
  # If API is cookie-based (not recommended for external APIs), CSRF would be needed.
  protect_from_forgery with: :null_session

  attr_reader :current_api_user

  protected # Make methods available to subclasses, but not as actions

  def authenticate_api_user!
    token = request.headers['Authorization']&.split(' ')&.last
    unless token
      return render_error('Authorization token missing', :unauthorized)
    end

    session_record = Session.find_by(token: token)
    if session_record && session_record.expires_at > Time.current
      @current_api_user = session_record.user
      # Optionally, update session_record.expires_at here if implementing sliding sessions
    else
      @current_api_user = nil
      render_error('Invalid or expired token', :unauthorized)
    end
  end

  private

  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end

  def render_success(data, status = :ok)
    if data.nil?
      head status
    else
      render json: data, status: status
    end
  end

  # Example of how current_user might be set for API context
  # attr_reader :current_api_user
  # def current_user
  #   @current_api_user
  # end
end
