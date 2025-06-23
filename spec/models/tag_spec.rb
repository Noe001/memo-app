require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:tag)).to be_valid
    end

    it 'can create a tag with memos trait' do
      tag = create(:tag, :with_memos)
      expect(tag.memos.count).to eq(2)
    end
  end

  describe 'associations' do
    it { should have_many(:memo_tags).dependent(:destroy) }
    it { should have_many(:memos).through(:memo_tags) }
  end

  describe 'validations' do
    subject { build(:tag) } # Using subject for uniqueness tests

    context 'name' do
      it { should validate_presence_of(:name) }
      it { should validate_uniqueness_of(:name).case_insensitive }
    end

    context 'color' do
      it { should allow_value('#123').for(:color) }
      it { should allow_value('#123456').for(:color) }
      it { should allow_value('#ABCDEF').for(:color) }
      it { should allow_value('#abcdef').for(:color) }
      it { should allow_value(nil).for(:color) } # Assuming color can be blank
      it { should allow_value('').for(:color) }   # Assuming color can be blank

      it { should_not allow_value('123456').for(:color).with_message('is invalid') }
      it { should_not allow_value('#12345').for(:color).with_message('is invalid') }
      it { should_not allow_value('#GH1234').for(:color).with_message('is invalid') }
      it { should_not allow_value('blue').for(:color).with_message('is invalid') }
    end
  end

  describe 'callbacks' do
    context 'before_save :downcase_name' do
      it 'converts name to lowercase before saving' do
        tag = create(:tag, name: 'TagName')
        expect(tag.name).to eq('tagname')
      end

      it 'does not alter an already lowercase name' do
        tag = create(:tag, name: 'lowercase')
        expect(tag.name).to eq('lowercase')
      end
    end
  end

  describe 'scopes' do
    describe '.popular' do
      let!(:tag1) { create(:tag, name: 'popular_tag') }
      let!(:tag2) { create(:tag, name: 'less_popular_tag') }
      let!(:tag3) { create(:tag, name: 'unpopular_tag') } # No memos

      before do
        create_list(:memo, 3).each { |memo| memo.tags << tag1 }
        create_list(:memo, 1).each { |memo| memo.tags << tag2 }
        # tag3 has no memos
      end

      it 'orders tags by the number of associated memos in descending order' do
        # Note: The scope only orders by count. It doesn't filter out tags with no memos by default.
        # If unpopular_tag is also selected, its position depends on DB's handling of COUNT(memos.id) for non-joined items,
        # but typically it would have a count of 0 or be excluded by the join.
        # `joins(:memos)` means only tags with memos will be included.
        popular_tags = Tag.popular
        expect(popular_tags.first).to eq(tag1)
        expect(popular_tags.second).to eq(tag2)
        expect(popular_tags).not_to include(tag3) # Due to inner join in the scope
        expect(popular_tags.length).to eq(2)
      end

      it 'returns most popular tag first' do
        expect(Tag.popular.first.name).to eq('popular_tag')
      end
    end
  end

  describe '.find_or_create_by_name' do
    context 'when tag exists' do
      let!(:existing_tag) { create(:tag, name: 'existing') }

      it 'finds the existing tag (case-insensitive)' do
        found_tag = Tag.find_or_create_by_name('EXISTING')
        expect(found_tag).to eq(existing_tag)
      end

      it 'does not create a new tag' do
        expect {
          Tag.find_or_create_by_name('Existing')
        }.not_to change(Tag, :count)
      end

      it 'returns the tag with downcased name' do
        # The method itself calls find_or_create_by(name: name.downcase)
        # and the model has a before_save callback to downcase.
        # So, the found tag should have a downcased name.
        tag = Tag.find_or_create_by_name('EXISTING')
        expect(tag.name).to eq('existing')
      end
    end

    context 'when tag does not exist' do
      it 'creates a new tag' do
        expect {
          Tag.find_or_create_by_name('NewTag')
        }.to change(Tag, :count).by(1)
      end

      it 'creates the tag with a downcased name' do
        tag = Tag.find_or_create_by_name('NewTag')
        expect(tag.name).to eq('newtag')
      end

      it 'returns the newly created tag' do
        tag = Tag.find_or_create_by_name('AnotherNew')
        expect(tag).to be_a(Tag)
        expect(tag.name).to eq('anothernew')
        expect(tag).to be_persisted
      end
    end
  end
end
