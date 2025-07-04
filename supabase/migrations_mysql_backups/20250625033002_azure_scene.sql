-- 開発用データベースの作成
CREATE DATABASE IF NOT EXISTS memo_app_development CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- テスト用データベースの作成
CREATE DATABASE IF NOT EXISTS memo_app_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ユーザーに権限を付与
GRANT ALL PRIVILEGES ON memo_app_development.* TO 'memo_user'@'%';
GRANT ALL PRIVILEGES ON memo_app_test.* TO 'memo_user'@'%';

FLUSH PRIVILEGES;