class MemoCopier
  attr_reader :original_memo, :target_user, :params

  def initialize(original_memo, target_user, params = {})
    @original_memo = original_memo
    @target_user = target_user
    @params = params
  end

  def call
    new_memo = target_user.memos.build(memo_attributes)

    if new_memo.save
      ServiceResult.new(success: true, memo: new_memo)
    else
      ServiceResult.new(success: false, memo: new_memo)
    end
  end

  private

  def memo_attributes
    # We now pass `tags_string` directly to the model, which handles the logic.
    base_attributes = {
      title: original_memo.title,
      description: original_memo.description,
      visibility: :private_memo
    }
    base_attributes.merge(params.slice(:title, :description, :visibility, :tags_string))
  end
end

# A simple class to return the result of a service.
class ServiceResult
  attr_reader :memo

  def initialize(success:, memo:)
    @success = success
    @memo = memo
  end

  def success?
    @success
  end
end
