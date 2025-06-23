require 'rails_helper'

RSpec.describe MemoTag, type: :model do
  describe 'factory' do
    # MemoTag doesn't typically have its own factory, it's created via associations.
    # However, if one were needed for direct testing:
    # it 'has a valid factory' do
    #   memo = create(:memo)
    #   tag = create(:tag)
    #   expect(build(:memo_tag, memo: memo, tag: tag)).to be_valid
    # end
  end

  describe 'associations' do
    it { should belong_to(:memo) }
    it { should belong_to(:tag) }
  end

  describe 'validations' do
    context 'uniqueness of memo_id scoped to tag_id' do
      let(:memo) { create(:memo) }
      let(:tag) { create(:tag) }

      before do
        # Create an initial MemoTag association
        create(:memo_tag, memo: memo, tag: tag)
      end

      it 'is valid with a unique memo_id and tag_id combination' do
        another_memo = create(:memo)
        another_tag = create(:tag)
        expect(build(:memo_tag, memo: memo, tag: another_tag)).to be_valid
        expect(build(:memo_tag, memo: another_memo, tag: tag)).to be_valid
      end

      it 'is invalid if the memo_id and tag_id combination is not unique' do
        duplicate_memo_tag = build(:memo_tag, memo: memo, tag: tag)
        expect(duplicate_memo_tag).not_to be_valid
        expect(duplicate_memo_tag.errors[:memo_id]).to include('has already been taken')
      end

      it 'requires memo_id' do
        # This is implicitly tested by `belongs_to` usually,
        # but good to ensure it's not possible to create without memo.
        expect(build(:memo_tag, memo: nil, tag: tag)).not_to be_valid
      end

      it 'requires tag_id' do
        expect(build(:memo_tag, memo: memo, tag: nil)).not_to be_valid
      end
    end
  end

  describe 'database constraints' do
    # It's good practice to also have a unique index in the database
    # to ensure data integrity at the DB level.
    # This test would require checking the schema or trying to save
    # a duplicate record with `validate: false`.
    # Example:
    # it 'has a unique index on [memo_id, tag_id]' do
    #   memo = create(:memo)
    #   tag = create(:tag)
    #   create(:memo_tag, memo: memo, tag: tag)
    #   expect {
    #     MemoTag.new(memo_id: memo.id, tag_id: tag.id).save(validate: false)
    #   }.to raise_error(ActiveRecord::RecordNotUnique) # Or appropriate DB error
    # end
    # This test is commented out as it depends on the specific DB setup and error.
  end
end
