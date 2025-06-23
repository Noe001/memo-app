source "https://rubygems.org"

ruby "3.2.3"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.3", ">= 7.1.3.3"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use mysql as the database for Active Record
gem "mysql2", "~> 0.5"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# パフォーマンス最適化
gem "kaminari"  # ページネーション
gem "counter_culture"  # カウンターキャッシュ

# セキュリティ
gem "rack-attack"  # レート制限
gem "secure_headers"  # セキュリティヘッダー

# UI/UX改善
gem "image_processing", "~> 1.2"
gem "lucide-rails", "~> 0.1"  # Active Storage variants

# API機能
gem "rack-cors"  # CORS対応

# 監視・ログ
gem "lograge"  # ログ最適化

group :development, :test do
  # デバッグ
  gem "debug", platforms: %i[ mri windows ]
  
  # テスト
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  
  # コード品質
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "brakeman", require: false  # セキュリティ監査
  
  # パフォーマンス分析
  gem "bullet"  # N+1クエリ検出
  
  # 開発支援
  gem "annotate"  # モデルにスキーマ情報を追加
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  
  # 開発効率化
  gem "letter_opener"  # メール確認
  gem "listen", "~> 3.3"
  gem "spring"
  gem "spring-watcher-listen", "~> 2.0.0"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver", ">= 4.22.0"
  gem "launchy"
  
  # テストカバレッジ
  gem "simplecov", require: false
  gem "simplecov-console", require: false
  
  # テスト支援
  gem "faker"  # テストデータ生成
  gem "timecop"  # 時間操作
  gem "vcr"  # HTTP録画・再生
  gem "webmock"  # HTTP mock
end

group :production do
  # 本番環境用
  gem "rack-timeout"  # タイムアウト設定
end
