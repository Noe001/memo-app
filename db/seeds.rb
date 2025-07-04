# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# サンプルユーザーを作成
unless User.exists?(email: 'test@example.com')
  user = User.create!(
    name: 'テストユーザー',
    email: 'test@example.com',
    password: 'password',
    password_confirmation: 'password'
  )
  puts "テストユーザーを作成しました: #{user.email}"
end

# サンプルメモを作成
if User.exists?(email: 'test@example.com')
  user = User.find_by(email: 'test@example.com')
  
  unless user.memos.exists?
    memo = user.memos.create!(
      title: 'サンプルメモ',
      description: 'これはサンプルのメモです。',
      visibility: :private_memo
    )
    puts "サンプルメモを作成しました: #{memo.title}"
  end
end

puts "シードデータの作成が完了しました。"
