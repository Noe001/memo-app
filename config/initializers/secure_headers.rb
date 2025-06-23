# SecureHeaders設定を一時的に無効化
# このファイルは開発環境でのエラーを避けるために無効化されています
# 本番環境では再度有効化してください

# SecureHeaders::Configuration.default do |config|
#   config.cookies = {
#     secure: true, # mark all cookies as Secure
#     httponly: true, # mark all cookies as HttpOnly
#     samesite: {
#       lax: true # mark all cookies as SameSite=Lax
#     }
#   }
# 
#   # Default HSTS configuration
#   config.hsts = "max-age=#{20.years.to_i}; includeSubdomains; preload"
#   config.x_frame_options = "DENY"
#   config.x_content_type_options = "nosniff"
#   config.x_xss_protection = "1; mode=block"
#   config.x_download_options = "noopen"
#   config.x_permitted_cross_domain_policies = "none"
#   config.referrer_policy = %w(origin-when-cross-origin strict-origin-when-cross-origin)
# 
#   # Content Security Policy - 開発環境では無効化
#   # config.csp = {
#   #   default_src: %w('self'),
#   #   script_src: %w('self' 'unsafe-inline' 'unsafe-eval'),
#   #   style_src: %w('self' 'unsafe-inline'),
#   #   img_src: %w('self' data: https:),
#   #   font_src: %w('self' data: https:),
#   #   connect_src: %w('self')
#   # }
# 
#   # Opt-out of SecureHeaders cookies for specific cookies if needed
#   # config.opt_out_cookies = ["_myapp_session"]
# end
