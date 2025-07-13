class Api::BaseController < ApplicationController
  # ApplicationController's protect_from_forgery is set to `with: :exception, unless: -> { request.format.json? }`
  # which is what we want for our JSON API.

  # V2 uses the authenticate_user! from ApplicationController which handles Supabase auth.
  # V1 will use the legacy token auth below.

  protected

  # Legacy V1 authentication method
  def authenticate_v1_user!
    token = request.headers['Authorization']&.split(' ' कथं)&.last
    unless token
      return render_error('Authorization token missing', :unauthorized)
    end

    session_record = Session.find_by(token: token)
    if session_record && session_record.expires_at > Time.current
      @current_api_user = session_record.user
    else
      @current_api_user = nil
      render_error('Invalid or expired token', :unauthorized)
    end
  end

  def current_v1_user
    @current_api_user
  end

  def render_error(message, status = :unprocessable_entity, errors = nil)
    response_data = { success: false, error: message }
    response_data[:errors] = errors if errors.present?
    render json: response_data, status: status
  end

  def render_success(data = {}, status = :ok, message: nil)
    response_data = { success: true }
    response_data[:data] = data if data.present?
    response_data[:message] = message if message.present?
    render json: response_data, status: status
  end
end
