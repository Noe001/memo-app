FactoryBot.define do
  factory :memo do
    sequence(:title) { |n| "メモタイトル#{n}" }
    sequence(:description) { |n| "これは#{n}番目のメモの内容です。" }
    visibility { :private_memo }
    association :user
    
    trait :public do
      visibility { :public_memo }
    end
    
    trait :shared do
      visibility { :shared }
    end
    
    trait :with_tags do
      after(:create) do |memo|
        create_list(:tag, 2).each do |tag|
          memo.tags << tag
        end
      end
    end
    
    trait :long_content do
      title { "非常に長いタイトル" * 10 }
      description { "非常に長い内容です。" * 100 }
    end
    
    trait :empty_content do
      title { "" }
      description { "" }
    end
    
    trait :title_only do
      title { "タイトルのみ" }
      description { "" }
    end
    
    trait :description_only do
      title { "" }
      description { "内容のみ" }
    end
  end
end 
