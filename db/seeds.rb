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
unless User.exists?(email: 'takumi.test@tateito.co.jp')
  user = User.create!(
    name: 'テストユーザー',
    email: 'takumi.test@tateito.co.jp',
    password: 'testpassword',
    password_confirmation: 'testpassword'
  )
  puts "テストユーザーを作成しました: #{user.email}"
end

# サンプルメモを作成
if User.exists?(email: 'takumi.test@tateito.co.jp')
  user = User.find_by(email: 'takumi.test@tateito.co.jp')
  
  unless user.memos.exists?
    memo = user.memos.create!(
      title: 'サンプルメモ',
      content: 'これはサンプルのメモです。',
      visibility: 'private'
    )
    puts "サンプルメモを作成しました: #{memo.title}"
  end
end

puts "シードデータの作成が完了しました。"
