# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# カバレッジ測定
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  minimum_coverage 90
end

# FactoryBot設定
require 'factory_bot_rails'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This can be changed. It is recommended that
# you do not name files matching this glob to end with _spec.rb. It makes
# `spec --pattern` useless.
#
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # FactoryBot設定
  config.include FactoryBot::Syntax::Methods
  
  # Database Cleaner設定
  config.use_transactional_fixtures = true
  
  # メタデータに基づく設定
  config.infer_spec_type_from_file_location!
  
  # Rails 5.1以降のフィルタ
  config.filter_rails_from_backtrace!
  
  # 認証ヘルパー
  config.include SessionHelpers, type: :controller
  config.include SessionHelpers, type: :request
  config.include SessionHelpers, type: :system
  
  # フォームヘルパー
  config.include ActionView::Helpers::FormHelper
  
  # システムスペック設定
  config.before(:each, type: :system) do
    driven_by :rack_test
  end
  
  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
  
  # テスト実行前の設定
  config.before(:suite) do
    # テストデータベースの初期化
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
  end
end

# shoulda-matchers設定
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
