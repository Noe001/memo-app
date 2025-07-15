FactoryBot.define do
  factory :memo do
    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph }
    visibility { 'private_memo' }
    user

    trait :public do
      visibility { 'public_memo' }
    end

    trait :with_tags do
      after(:create) do |memo|
        create_list(:memo_tag, 3, memo: memo)
      end
    end

    trait :invalid do
      title { nil }
    end
  end
end
