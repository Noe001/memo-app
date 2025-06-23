require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MemoApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    
    # 最小限の設定のみ
    config.time_zone = "Tokyo"
    config.i18n.default_locale = :ja
    
    # セッション設定（最もシンプル）
    config.session_store :cookie_store, key: '_memo_session'
    
    # SecureHeadersミドルウェアを明示的に削除
    config.middleware.delete "SecureHeaders::Middleware" if defined?(SecureHeaders::Middleware)
  end
end
