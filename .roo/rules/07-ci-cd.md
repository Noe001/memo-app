# CI/CD・自動化ルール

- GitHub ActionsやCIでrubocop, brakeman, rspec, eslint, prettier, jest, playwright等の自動実行を必須とします。
- main/masterブランチへの直接pushは禁止し、必ずPR経由でマージしてください。
- テストカバレッジは90%以上を維持してください。
- CI上で `docker compose up/down` による統合テストを実施してください。 
