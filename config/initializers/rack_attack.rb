class Rack::Attack
  # `Rack::Attack` is configured to use the Rails cache store.
  # Configure a different cache store for Rack::Attack, if needed.
  # self.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Allow all local traffic
  safelist('allow from localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # Throttle POST requests to /login and /session (SessionsController#create) by IP address
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle('logins/ip', limit: 5, period: 60.seconds) do |req|
    if (req.path == '/login' || req.path == '/session') && req.post?
      req.ip
    end
  end

  # Throttle POST requests to /login and /session (SessionsController#create) by email parameter
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{req.params['email'].to_s.downcase.gsub(/\s+/, "")}"
  # Normalize the email parameter for consistent tracking.
  throttle('logins/email', limit: 10, period: 1.hour) do |req|
    if (req.path == '/login' || req.path == '/session') && req.post?
      req.params['email'].to_s.downcase.gsub(/\s+/, "").presence
    end
  end

  # Throttle POST requests to /signup (UsersController#create) by IP address
  # Key: "rack::attack:#{Time.now.to_i/:period}:signups/ip:#{req.ip}"
  throttle('signups/ip', limit: 10, period: 1.hour) do |req|
    if req.path == '/signup' && req.post?
      req.ip
    end
  end

  # Custom response for throttled requests
  # Override the default response if you want to customize it
  self.throttled_response = lambda do |env|
    status_code = 429
    body = {
      error: "Too many requests. Please try again later."
    }.to_json

    [status_code, {'Content-Type' => 'application/json'}, [body]]
  end

  # ActiveSupport::Notifications subscribers can be used to track Rack::Attack events.
  # ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  #   req = payload[:request]
  #   if %i[throttle blocklist].include?(req.env['rack.attack.match_type'])
  #     Rails.logger.info "[Rack::Attack][#{req.env['rack.attack.match_type']}] IP: #{req.ip} Path: #{req.path} UserID: #{req.env['warden']&.user&.id}"
  #   end
  # end
end

# Make sure Rack::Attack is active in development and test environments
# In production, it's usually active by default.
# Rails.application.config.middleware.use Rack::Attack unless Rails.env.production?

Rails.application.config.middleware.use Rack::Attack

# Configure which cache store to use.
# Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new # For example

# Log throttled requests
ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
  if payload[:request].env['rack.attack.matched'] && payload[:request].env['rack.attack.match_type'] == :throttle
    Rails.logger.info "[Rack::Attack][THROTTLED] Remote IP: \"#{payload[:request].ip}\", Path: \"#{payload[:request.path]}\", Email: \"#{payload[:request].params['email']}\""
  end
end
