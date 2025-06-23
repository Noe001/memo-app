FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "tag#{n}" }
    color { '#007bff' }
    description { 'テストタグです' }
    
    trait :red do
      color { '#dc3545' }
    end
    
    trait :green do
      color { '#28a745' }
    end
    
    trait :yellow do
      color { '#ffc107' }
    end
    
    trait :with_memos do
      after(:create) do |tag|
        create_list(:memo, 2).each do |memo|
          tag.memos << memo
        end
      end
    end
  end
end 
