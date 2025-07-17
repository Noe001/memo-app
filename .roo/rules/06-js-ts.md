# JavaScript/TypeScriptプロジェクト向けルール

- Linter（eslint）とFormatter（prettier）を必ず利用してください。
- supabase-js, playwright等の依存パッケージはバージョンを固定し、lockファイル（package-lock.json等）を厳守してください。
- テストはjestやplaywright等で自動化し、CIで必ず実行してください。
- コードはES6+の構文を推奨し、型安全性のためTypeScriptの活用を推奨します。 
