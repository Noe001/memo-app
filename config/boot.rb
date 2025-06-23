ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# SecureHeadersを一時的に無効化
begin
  require 'secure_headers'
  SecureHeaders::Configuration.default do |config|
    config.csp = false
    config.hsts = false
    config.x_frame_options = false
    config.x_content_type_options = false
    config.x_xss_protection = false
    config.referrer_policy = false
  end
rescue LoadError
  # SecureHeadersがない場合は何もしない
end
