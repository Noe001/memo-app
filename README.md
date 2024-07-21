# README

### cloneしてから起動まで

$ docker compose build

$ docker compose up -d

$ docker compose exec app rails db:create

$ docker compose exec app rails db:reset # マイグレーションエラーが解消されない場合

$ docker compose exec app rails db:migrate
