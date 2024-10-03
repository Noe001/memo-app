FactoryBot.define do
  factory :memo do
    title { "test title" }
    description { "test description" }
    association :user
  end
end
