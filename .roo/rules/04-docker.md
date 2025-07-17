# Docker Compose運用ルール

- アプリケーションの起動・停止・再起動・ログ取得・ビルド・デプロイ等、アプリに関する全てのコマンド操作は必ず `docker compose` コマンドを使用してください。
- 直接 `docker run` や `docker build` などの単体コマンドは使わず、必ず `docker compose` を通して操作してください。
- サービスの追加・削除・設定変更も `docker-compose.yml` を編集し、`docker compose` コマンドで反映してください。
- 例：
  - 起動: `docker compose up -d`
  - 停止: `docker compose down`
  - ログ: `docker compose logs <サービス名>`
  - ビルド: `docker compose build`
- これらのルールは開発・本番・CI/CD等すべての環境で徹底してください。 
