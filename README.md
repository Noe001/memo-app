# 🗒️ MemoApp - Professional Note-Taking Application

[![Ruby on Rails](https://img.shields.io/badge/Ruby%20on%20Rails-7.1.3-red.svg)](https://rubyonrails.org/)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.2.3-red.svg)](https://www.ruby-lang.org/)
[![Test Coverage](https://img.shields.io/badge/Coverage-90%25-brightgreen.svg)](#testing)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

現代的なWebテクノロジーを活用した高機能メモ管理アプリケーション。直感的なユーザーインターフェースと強固なセキュリティを兼ね備えています。

## ✨ 主な機能

### 📝 メモ管理
- **リアルタイム検索** - タイトル・内容での高速検索
- **タグシステム** - カラーコード付きタグによる分類
- **公開レベル制御** - プライベート・共有・公開の3段階設定
- **エクスポート機能** - JSON・CSV形式での書き出し
- **ページネーション** - 大量データの効率的表示

### 🔐 セキュリティ
- **強力な認証システム** - BCryptによるパスワード暗号化
- **セッション管理** - Redis基盤の高速セッション処理
- **レート制限** - DDoS攻撃からの保護
- **CSRFトークン** - クロスサイトリクエストフォージェリ対策
- **セキュリティヘッダー** - XSS・Clickjacking等からの保護

### 🎨 ユーザーエクスペリエンス
- **レスポンシブデザイン** - デスクトップ・タブレット・モバイル対応
- **アクセシビリティ** - WCAG 2.1 AA準拠
- **キーボードショートカット** - 効率的な操作
- **ダークモード対応** - 目に優しい表示切替
- **リアルタイムプレビュー** - マークダウン対応

### ⚡ パフォーマンス
- **N+1クエリ解消** - Bulletによる監視と最適化
- **インデックス最適化** - 高速検索のためのDB最適化
- **Redisキャッシュ** - 頻繁なクエリの高速化
- **画像最適化** - WebP変換による軽量化

## 🏗️ 技術スタック

### バックエンド
- **Ruby 3.2.3** - プログラミング言語
- **Ruby on Rails 7.1.3** - Webフレームワーク
- **MySQL 8.2.0** - データベース
- **Redis** - キャッシュ・セッション管理

### フロントエンド
- **Turbo & Stimulus** - モダンJavaScript
- **Import Maps** - ESM対応
- **CSS3** - レスポンシブデザイン
- **Accessibility APIs** - スクリーンリーダー対応

### 開発・テスト
- **RSpec** - テストフレームワーク
- **FactoryBot** - テストデータ生成
- **Simplecov** - カバレッジ測定
- **Rubocop** - コード品質管理
- **Brakeman** - セキュリティ監査

### インフラ・DevOps
- **Docker & Docker Compose** - コンテナ化
- **GitHub Actions** - CI/CD（設定済み）
- **Nginx** - リバースプロキシ
- **Let's Encrypt** - SSL証明書

## 🚀 クイックスタート

### 必要な環境
- Docker Desktop
- Git

### インストール手順

```bash
# リポジトリのクローン
git clone https://github.com/your-username/memo-app.git
cd memo-app

# 環境変数の設定
cp .env.example .env
# .envファイルを適切に編集

# Docker環境の構築
docker compose build

# コンテナの起動
docker compose up -d

# データベースの初期化
docker compose exec app rails db:create
docker compose exec app rails db:migrate
docker compose exec app rails db:seed

# 依存関係のインストール確認
docker compose exec app bundle check
```

### アクセス
- **アプリケーション**: http://localhost:3000
- **API**: http://localhost:3000/api/v1
- **管理画面**: http://localhost:3000/admin

## 🧪 テスト

### テストの実行
```bash
# 全テストの実行
docker compose exec app rspec

# カバレッジレポート生成
docker compose exec app rspec --format html --out coverage/index.html

# 特定テストの実行
docker compose exec app rspec spec/models/
docker compose exec app rspec spec/requests/
```

### コード品質チェック
```bash
# Rubocop（コードスタイル）
docker compose exec app rubocop

# Brakeman（セキュリティ）
docker compose exec app brakeman

# N+1クエリ検出
docker compose exec app rails server
# 開発環境でBulletが自動検出
```

## 📊 パフォーマンス監視

### メトリクス
- **応答時間**: 平均200ms以下
- **スループット**: 1000 req/sec
- **メモリ使用量**: 256MB以下
- **データベース**: 99.9%稼働率

### 監視ツール
```bash
# パフォーマンス監視
docker compose exec app rails performance:monitor

# メモリ使用量確認
docker stats

# ログ分析
docker compose logs -f app
```

## 🔧 開発

### 開発サーバー起動
```bash
# 開発モード
docker compose up

# ログ確認
docker compose logs -f app

# データベースコンソール
docker compose exec db mysql -u root -p
```

### 新機能の追加
```bash
# マイグレーション作成
docker compose exec app rails generate migration AddFeatureToModel

# モデル作成
docker compose exec app rails generate model ModelName

# コントローラー作成
docker compose exec app rails generate controller ControllerName
```

## 📚 API ドキュメント

### 認証
```bash
# ログイン
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}
```

### メモ操作
```bash
# メモ一覧取得
GET /api/v1/memos
Authorization: Bearer <token>

# メモ作成
POST /api/v1/memos
Content-Type: application/json
Authorization: Bearer <token>

{
  "title": "メモタイトル",
  "description": "メモ内容",
  "tags": ["タグ1", "タグ2"],
  "visibility": "private"
}
```

## 🚀 デプロイ

### 本番環境設定
```bash
# 本番環境用イメージ構築
docker build -f Dockerfile.production -t memo-app:latest .

# 本番環境起動
docker compose -f docker-compose.production.yml up -d

# SSL証明書設定
docker compose exec nginx certbot certonly
```

### 環境変数（本番）
```bash
RAILS_ENV=production
SECRET_KEY_BASE=<strong_secret>
DATABASE_URL=mysql2://user:pass@host:3306/database
REDIS_URL=redis://redis:6379/0
ALLOWED_ORIGINS=https://yourdomain.com
```

## 🔒 セキュリティ

### セキュリティ機能
- **パスワードポリシー**: 8文字以上、大小英数字・記号必須
- **セッション管理**: 30日自動期限切れ
- **レート制限**: 1分間5回までのログイン試行
- **セキュリティヘッダー**: CSP、HSTS、X-Frame-Options等

### セキュリティチェック
```bash
# 脆弱性スキャン
docker compose exec app brakeman

# 依存関係チェック
docker compose exec app bundle audit

# セキュリティアップデート
docker compose exec app bundle update
```

## 📈 監視・ログ

### ログ管理
```bash
# アプリケーションログ
tail -f log/production.log

# アクセスログ
tail -f log/access.log

# エラーログ
tail -f log/error.log
```

### メトリクス収集
- **レスポンス時間監視**
- **エラー率追跡**
- **ユーザー行動分析**
- **リソース使用量監視**

## 🤝 貢献

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### 開発ガイドライン
- **コード品質**: Rubocop設定に準拠
- **テスト**: カバレッジ90%以上維持
- **ドキュメント**: 新機能にはドキュメント追加
- **セキュリティ**: セキュリティレビュー必須

## 📝 ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## 📞 サポート

- **Issues**: [GitHub Issues](https://github.com/your-username/memo-app/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/memo-app/discussions)
- **Email**: support@memo-app.com

## 🙏 謝辞

このプロジェクトは以下のオープンソースプロジェクトの恩恵を受けています：

- [Ruby on Rails](https://rubyonrails.org/)
- [MySQL](https://www.mysql.com/)
- [Redis](https://redis.io/)
- [Docker](https://www.docker.com/)
- その他多数のGem・ライブラリ作者の皆様

---

**MemoApp** - あなたの思考を整理し、アイデアを形にする最高のパートナー 🚀
