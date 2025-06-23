SecureHeaders::Configuration.default do |config|
  config.cookies = {
    secure: true, # mark all cookies as Secure
    httponly: true, # mark all cookies as HttpOnly
    samesite: {
      lax: true # mark all cookies as SameSite=Lax
    }
  }

  # Default HSTS configuration
  config.hsts = "max-age=#{20.years.to_i}; includeSubdomains; preload"
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = %w(origin-when-cross-origin strict-origin-when-cross-origin)

  # Content Security Policy
  # TEMPORARILY RELAXED FOR DEBUGGING UI ISSUES
  config.csp = SecureHeaders::CSP.new do |csp|
    # Extremely permissive for debugging:
    csp.default_src = %w('self' https: http: 'unsafe-inline' 'unsafe-eval' data: blob:)
    csp.script_src = %w('self' https: http: 'unsafe-inline' 'unsafe-eval' data: blob:)
    csp.style_src = %w('self' https: http: 'unsafe-inline' data: blob:)
    csp.img_src = %w('self' https: http: data: blob:)
    csp.font_src = %w('self' https: http: data: blob:)
    csp.connect_src = %w('self' https: http: ws: wss:) # For WebSockets if any

    # Keep these more restrictive if possible, but relax if needed for debug
    csp.base_uri = %w('self')
    csp.form_action = %w('self') # Or specific external form targets
    csp.frame_ancestors = %w('none') # Usually good to keep this DENY/'none'
    csp.object_src = %w('none') # Usually good to keep this 'none'

    # csp.report_uri = %w(/csp_violation_report_endpoint)
  end

  # Boolean CSP flags are set on the csp object itself
  # These are generally good to keep, even when relaxing sources.
  config.csp.block_all_mixed_content = true # CSP Level 2
  config.csp.upgrade_insecure_requests = true # CSP Level 2


  # Opt-out of SecureHeaders cookies for specific cookies if needed
  # config.opt_out_cookies = ["_myapp_session"]
end
