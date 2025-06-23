require 'rails_helper'

RSpec.describe Memo, type: :model do
  describe 'バリデーション' do
    it 'has a valid factory' do
      expect(build(:memo)).to be_valid
    end

    describe 'title' do
      it 'allows nil title' do
        memo = build(:memo, title: nil)
        expect(memo).to be_valid
      end

      it 'allows empty title' do
        memo = build(:memo, title: '')
        expect(memo).to be_valid
      end

      it 'maximum length: 255' do
        memo = build(:memo, title: 'a' * 256)
        expect(memo).not_to be_valid
        expect(memo.errors[:title]).to include('is too long (maximum is 255 characters)')
      end
    end

    describe 'description' do
      it 'allows nil description' do
        memo = build(:memo, description: nil)
        expect(memo).to be_valid
      end

      it 'allows empty description' do
        memo = build(:memo, description: '')
        expect(memo).to be_valid
      end

      it 'maximum length: 10000' do
        memo = build(:memo, description: 'a' * 10001)
        expect(memo).not_to be_valid
        expect(memo.errors[:description]).to include('is too long (maximum is 10000 characters)')
      end
    end

    describe 'title_or_description_present' do
      it 'requires either title or description' do
        memo = build(:memo, title: '', description: '')
        expect(memo).not_to be_valid
        expect(memo.errors[:base]).to include('Title or description must be present')
      end

      it 'valid with only title' do
        memo = build(:memo, title: 'タイトル', description: '')
        expect(memo).to be_valid
      end

      it 'valid with only description' do
        memo = build(:memo, title: '', description: '内容')
        expect(memo).to be_valid
      end

      it 'valid with both title and description' do
        memo = build(:memo, title: 'タイトル', description: '内容')
        expect(memo).to be_valid
      end
    end

    describe 'visibility' do
      it 'defaults to private_memo' do
        memo = create(:memo)
        expect(memo.visibility).to eq('private_memo')
      end

      it 'allows public_memo' do
        memo = build(:memo, visibility: :public_memo)
        expect(memo).to be_valid
      end

      it 'allows shared' do
        memo = build(:memo, visibility: :shared)
        expect(memo).to be_valid
      end
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:memo_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:memo_tags) }
  end

  describe 'enums' do
    it { should define_enum_for(:visibility).with_values(private_memo: 0, public_memo: 1, shared: 2) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:memo1) { create(:memo, user: user, created_at: 1.day.ago, updated_at: 1.hour.ago) }
    let!(:memo2) { create(:memo, user: user, created_at: 2.days.ago, updated_at: 2.hours.ago) }
    let!(:memo3) { create(:memo, user: user, created_at: 3.days.ago, updated_at: 3.hours.ago) }

    describe '.recent' do
      it 'orders by updated_at desc' do
        expect(Memo.recent).to eq([memo1, memo2, memo3])
      end
    end

    describe '.by_user' do
      let(:other_user) { create(:user) }
      let!(:other_memo) { create(:memo, user: other_user) }

      it 'returns memos for specific user' do
        expect(Memo.by_user(user)).to contain_exactly(memo1, memo2, memo3)
        expect(Memo.by_user(other_user)).to contain_exactly(other_memo)
      end
    end

    describe '.search' do
      let!(:searchable_memo1) { create(:memo, title: 'Ruby on Rails', description: 'フレームワーク') }
      let!(:searchable_memo2) { create(:memo, title: 'Python', description: 'Ruby言語ではない') }
      let!(:searchable_memo3) { create(:memo, title: 'JavaScript', description: 'フロントエンド') }

      it 'searches by title' do
        results = Memo.search('Ruby')
        expect(results).to contain_exactly(searchable_memo1, searchable_memo2)
      end

      it 'searches by description' do
        results = Memo.search('フレームワーク')
        expect(results).to contain_exactly(searchable_memo1)
      end

      it 'case insensitive search' do
        results = Memo.search('ruby')
        expect(results).to contain_exactly(searchable_memo1, searchable_memo2)
      end

      it 'returns empty for no matches' do
        results = Memo.search('存在しない')
        expect(results).to be_empty
      end
    end
  end

  describe 'factory traits' do
    it 'creates public memo' do
      memo = create(:memo, :public)
      expect(memo.visibility).to eq('public_memo')
    end

    it 'creates shared memo' do
      memo = create(:memo, :shared)
      expect(memo.visibility).to eq('shared')
    end

    it 'creates memo with tags' do
      memo = create(:memo, :with_tags)
      expect(memo.tags.count).to eq(2)
    end

    it 'creates memo with long content' do
      memo = create(:memo, :long_content)
      expect(memo.title.length).to be > 100
      expect(memo.description.length).to be > 1000
    end

    it 'creates title only memo' do
      memo = build(:memo, :title_only)
      expect(memo.title).to be_present
      expect(memo.description).to be_blank
      expect(memo).to be_valid
    end

    it 'creates description only memo' do
      memo = build(:memo, :description_only)
      expect(memo.title).to be_blank
      expect(memo.description).to be_present
      expect(memo).to be_valid
    end

    it 'creates invalid empty content memo' do
      memo = build(:memo, :empty_content)
      expect(memo).not_to be_valid
    end
  end

  describe 'tag operations' do
    let(:memo) { create(:memo) }
    let(:tag1) { create(:tag, name: 'ruby') }
    let(:tag2) { create(:tag, name: 'rails') }

    it 'can add tags' do
      memo.tags << tag1
      memo.tags << tag2
      expect(memo.tags).to contain_exactly(tag1, tag2)
    end

    it 'can remove tags' do
      memo.tags = [tag1, tag2]
      memo.tags.delete(tag1)
      expect(memo.tags).to contain_exactly(tag2)
    end
  end
end
