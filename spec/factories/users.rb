FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    
    trait :with_memos do
      after(:create) do |user|
        create_list(:memo, 3, user: user)
      end
    end
    
    trait :invalid_email do
      email { "invalid-email" }
    end
    
    trait :weak_password do
      password { "weak" }
      password_confirmation { "weak" }
    end
  end
end 
