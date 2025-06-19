# SecureHeadersを確実に無効化
if defined?(SecureHeaders)
  Rails.logger.info "SecureHeaders detected - configuring minimal settings"
  
  SecureHeaders::Configuration.default do |config|
    config.csp = false
    config.hsts = false
    config.x_frame_options = false
    config.x_content_type_options = false
    config.x_xss_protection = false
    config.referrer_policy = false
  end
  
  Rails.logger.info "SecureHeaders configured with all policies disabled"
else
  Rails.logger.info "SecureHeaders not loaded"
end

# ミドルウェアからも削除
Rails.application.config.middleware.delete "SecureHeaders::Middleware" if defined?(SecureHeaders::Middleware) 
