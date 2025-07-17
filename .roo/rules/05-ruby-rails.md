# Ruby/Railsプロジェクト向けルール

- Rubocop, Brakeman, RSpec, FactoryBot, shoulda-matchers, database_cleaner, annotate などのツールを必ず活用してください。
- migration/seed/rollback等のDB操作は必ず `docker compose` 経由で実行してください。
- ActiveRecordのバリデーション・コールバックを積極的に活用してください。
- 認可はPunditまたはCancancan等のgemで厳格に管理してください。
- Gemfileのバージョンは固定し、定期的にアップデートしてください。 
