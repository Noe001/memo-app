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
  # Starts with a restrictive policy and can be expanded as needed.
  config.csp = SecureHeaders::CSP.new do |csp|
    csp.default_src = %w('self')
    csp.base_uri = %w('self')
    csp.font_src = %w('self' https: data:) # Allow https and data URIs for fonts
    csp.form_action = %w('self')
    csp.frame_ancestors = %w('none') # Equivalent to X-Frame-Options: DENY
    csp.img_src = %w('self' https: data:) # Allow https and data URIs for images
    csp.object_src = %w('none')
    # 'unsafe-inline' is often needed for Rails UJS and legacy JavaScript.
    # 'unsafe-eval' might be needed by some JS libraries.
    # Consider using a nonce-based approach for inline scripts/styles for better security.
    # Add CDNs here if needed: e.g. 'https://cdn.example.com'
    csp.script_src = %w('self' 'unsafe-inline' 'unsafe-eval')
    # 'unsafe-inline' for inline styles. Add CDNs here if needed.
    csp.style_src = %w('self' 'unsafe-inline')
    # csp.report_uri = %w(/csp_violation_report_endpoint) # Enable if you have an endpoint to collect reports
  end

  # Boolean CSP flags are set on the csp object itself
  config.csp.block_all_mixed_content = true # CSP Level 2
  config.csp.upgrade_insecure_requests = true # CSP Level 2


  # Opt-out of SecureHeaders cookies for specific cookies if needed
  # config.opt_out_cookies = ["_myapp_session"]
end
