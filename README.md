# MemoApp (Rails × Supabase)

## 1. 前提条件
* Docker / Docker Compose
* Node.js 18+（`npx` が使えれば OK）
* Supabase CLI → `npm install -D supabase` または Homebrew で `brew install supabase/tap/supabase`

## 2. ローカル開発手順
```bash
# リポジトリ取得
git clone <repo-url>
cd memo-app

# 依存イメージのビルド
docker compose build --no-cache

# コンテナ起動（Rails + Postgres + Redis）
docker compose up -d

# データベース準備（createやmigrate、seedを状況に合わせて行ってくれる）
docker compose exec app bundle exec rails db:prepare

# Supabase スタック起動（別ターミナル）
# migrations に MySQL 用 SQL が残っている場合は退避してから実行
npx supabase start
```
利用ポート
* Rails : http://localhost:3000
* Supabase Studio : http://localhost:54323

停止は `docker compose down` / `npx supabase stop` で行えます。

## 3. Supabase とクラウド連携
```bash
# プロジェクトをダッシュボードで作成し、Project Ref を取得
npx supabase link --project-ref <PROJECT_REF>

# ローカル schema をクラウドへ反映
npx supabase db push --verbose
```
マイグレーション差分を生成する場合は `npx supabase db diff -f <file>.sql` を使用してください。

## 4. よく使うコマンド
| 操作 | コマンド |
| ---- | -------- |
| Rails テスト | `docker compose exec app rspec` |
| Supabase Edge Function 生成 | `npx supabase functions new <name>` |
| Edge Function デプロイ | `npx supabase functions deploy <name>` |
| CLI 更新 | `npm update supabase --save-dev` |

---
MIT License ©️ 2025 MemoApp
