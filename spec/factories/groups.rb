FactoryBot.define do
  factory :group do
    name { 'Test Group' }
    description { 'This is a test group.' }
    association :owner, factory: :user
  end
end
