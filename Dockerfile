FROM ruby:3.2.3-slim

# 必要なパッケージのインストール
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    default-mysql-client \
    default-libmysqlclient-dev \
    git \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# アプリケーションディレクトリの作成
WORKDIR /app

# Gemfileをコピーして依存関係をインストール
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'false' && \
    bundle config set --local without 'production' && \
    bundle install

# アプリケーションコードをコピー
COPY . .

# アセットのプリコンパイル（開発環境では不要だが、念のため）
# RUN RAILS_ENV=development bundle exec rails assets:precompile

# ポート3000を公開
EXPOSE 3000

# サーバー起動コマンド
CMD ["rails", "server", "-b", "0.0.0.0"]