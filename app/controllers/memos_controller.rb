class MemosController < ApplicationController
  before_action :authenticate_user!
  # `set_memo` now fetches any memo, authorization is done separately.
  before_action :set_memo, only: [:show, :update, :destroy, :add_memo] # add_memo uses @selected
  before_action :authorize_memo_owner_for_write, only: [:update, :destroy]
  before_action :authorize_memo_for_read, only: [:show] # New authorization for show

  def index
    @user = current_user
    @memo_new = current_user.memos.build
    @memos = current_user.memos.includes(:tags).recent.page(params[:page])
    @tags = current_user.memos.joins(:tags).group('tags.name').count
    
    # Removed logic that loaded a specific @selected memo by params[:id] in index.
    # Details of a specific memo should be viewed via the `show` action.
  end

  def show
    # @selected is set by set_memo and authorized by authorize_memo_for_read
    # The following lines seem to be for re-rendering index's list part,
    # which might be confusing if show is meant to display only one memo.
    # Consider a dedicated view for `show` or simplifying.
    @user = current_user
    @memo_new = current_user.memos.build # For a new memo form, perhaps in a sidebar
    @memos = current_user.memos.includes(:tags).recent.page(params[:page]) # List for sidebar
    @tags = current_user.memos.joins(:tags).group('tags.name').count # Tags for sidebar

    # Logic for "add this memo to my list" (if @selected is viewable and not owned)
    if @selected.user_id != current_user.id # Check if the selected memo is not owned by current user
      @can_add_selected_memo = true # Flag to show "add to my memos" button
      @memo_to_add = current_user.memos.build(
        title: @selected.title,
        description: @selected.description,
        visibility: :private_memo # Default to private when copying
        # Tags are not copied by default here, could be an enhancement
      )
    else
      @can_add_selected_memo = false
    end
    # The view for 'show' (e.g., show.html.erb) should primarily focus on @selected.
    # If it reuses the index template, these extra variables are needed.
    # For now, assuming it might render index or a similar layout.
    render :index # This was the original behavior, keeping it for now.
  end

  # This action is for when a user (current_user) wants to copy a visible memo (@selected)
  # (that they might not own) to their own list of memos.
  def add_memo
    # @selected is set by set_memo. We need to ensure current_user can *read* @selected.
    # Re-purposing authorize_memo_for_read, or creating a specific one.
    # For now, let's assume if they got to the button to trigger this, they could see it.
    # A more robust check would be to call authorize_memo_for_read here too.
    # However, authorize_memo_for_read redirects. Let's handle it manually:
    unless can_read_memo?(@selected, current_user)
      redirect_to root_path, alert: 'このメモを閲覧または追加する権限がありません。'
      return
    end

    # Build the new memo for the current user, copying content from @selected.
    @memo_to_add_to_own_list = current_user.memos.build(
      title: @selected.title,
      description: @selected.description,
      visibility: memo_params_for_add[:visibility] || :private_memo # User can choose visibility for their copy
      # Tags from @selected are not automatically copied here.
      # If params[:tags] is intended for the new copy, it should be handled.
    )
    
    if @memo_to_add_to_own_list.save
      # If params[:tags] are submitted with the "add_memo" form for the *new* memo
      process_tags(@memo_to_add_to_own_list, params.dig(:memo, :tags_string) || params[:tags_string]) if params.dig(:memo, :tags_string).present? || params[:tags_string].present?
      redirect_to memo_path(@memo_to_add_to_own_list), notice: 'メモをあなたのリストに追加しました。'
    else
      # In case of failure, re-render the 'show' view of the original @selected memo
      # or redirect to where the "add" button was.
      # This part needs careful thought for UX. For now, re-render show's context.
      flash.now[:alert] = "メモの追加に失敗しました: #{@memo_to_add_to_own_list.errors.full_messages.join(', ')}"
      # Re-populate variables needed for rendering the 'show' view (which then renders 'index')
      @user = current_user
      @memo_new = current_user.memos.build
      @memos = current_user.memos.includes(:tags).recent.page(params[:page])
      @tags = current_user.memos.joins(:tags).group('tags.name').count
      if @selected.user_id != current_user.id
        @can_add_selected_memo = true
        # Rebuild @memo_to_add with submitted params if they exist, else from @selected
        # This assumes memo_params_for_add might be submitted via a form for add_memo
        submitted_title = params.dig(:memo, :title) || @selected.title
        submitted_description = params.dig(:memo, :description) || @selected.description
        submitted_visibility = params.dig(:memo, :visibility) || :private_memo

        @memo_to_add = current_user.memos.build(
          title: submitted_title,
          description: submitted_description,
          visibility: submitted_visibility
        )
        @memo_to_add.errors.merge!(@memo_to_add_to_own_list.errors) # Show errors on this form object
      else
        @can_add_selected_memo = false
      end
      render :index, status: :unprocessable_entity
    end
  end

  def create
    @memo_new = current_user.memos.build(memo_params)
    
    if @memo_new.save
      process_tags(@memo_new, params[:tags]) if params[:tags].present?
      redirect_to memo_path(@memo_new), notice: 'メモを作成しました'
    else
      @memos = current_user.memos.includes(:tags).recent.page(params[:page])
      @tags = current_user.memos.joins(:tags).group('tags.name').count
      flash.now[:alert] = 'メモの保存に失敗しました'
      render :index
    end
  end

  def update
    if @selected.update(memo_params)
      process_tags(@selected, params[:tags]) if params[:tags].present?
      redirect_to memo_path(@selected), notice: 'メモを更新しました'
    else
      @memos = current_user.memos.includes(:tags).recent.page(params[:page])
      @memo_new = current_user.memos.build
      @tags = current_user.memos.joins(:tags).group('tags.name').count
      flash.now[:alert] = 'メモの更新に失敗しました'
      render :index
    end
  end

  def destroy
    if @selected.destroy
      redirect_to root_path, notice: 'メモを削除しました'
    else
      redirect_to memo_path(@selected), alert: 'メモの削除に失敗しました'
    end
  end

  def search
    @user = current_user
    @memo_new = current_user.memos.build
    search_word = params[:word]
    @memos = current_user.memos.includes(:tags).search(search_word).recent.page(params[:page])
    @tags = current_user.memos.joins(:tags).group('tags.name').count
    # Removed @selected = Memo.includes(:user, :tags).find_by(id: params[:id])
    # Search results are primary. Viewing details should go through `show` action for a specific memo.
    
    if @memos.empty? && search_word.present? # Only show if a search was actually performed
      flash.now[:alert] = "「#{search_word}」に該当するメモは見つかりませんでした"
    end
    
    render :index
  end



  private

  def set_memo
    # Fetches any memo by ID, includes associations for efficiency.
    # Authorization is handled by separate before_actions.
    @selected = Memo.includes(:user, :tags).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: '指定されたメモが見つかりません。'
  end

  # For write actions (update, destroy)
  def authorize_memo_owner_for_write
    unless @selected.user_id == current_user.id
      redirect_to root_path, alert: 'このメモを編集または削除する権限がありません。'
    end
  end

  # For read actions (show, potentially add_memo's source)
  def authorize_memo_for_read
    unless can_read_memo?(@selected, current_user)
      redirect_to root_path, alert: 'このメモを閲覧する権限がありません。'
    end
  end

  # Helper method to check read access, used in controller and potentially views.
  # Not using helper_method as it's controller-internal logic primarily.
  def can_read_memo?(memo, user)
    return false unless memo && user
    # Owner can always read
    return true if memo.user_id == user.id
    # Public memos can be read by anyone
    return true if memo.public_memo? # Assumes enum method public_memo? exists
    # Shared memos logic (currently not implemented, so shared are private to owner)
    # return true if memo.shared? && memo.is_shared_with?(user)
    false # Default to no access
  end

  def memo_params # For create and update of own memos
    params.require(:memo).permit(:title, :description, :visibility, :tags_string)
  end

  # Specific params for the 'add_memo' action when copying a memo.
  # Allows user to set their own visibility for the copy.
  def memo_params_for_add
    params.require(:memo).permit(:title, :description, :visibility, :tags_string)
  end

  def process_tags(memo, tag_names_string)
    return if tag_names_string.blank?

    target_tag_names = tag_names_string.split(',').map(&:strip).reject(&:blank?).map(&:downcase).uniq

    return if target_tag_names.empty?

    existing_tags = Tag.where(name: target_tag_names).to_a
    existing_tag_names = existing_tags.map(&:name)

    new_tag_names = target_tag_names - existing_tag_names

    created_tags = []
    if new_tag_names.any?
      # Tag.find_or_create_by_name handles downcasing and ensures uniqueness correctly.
      # Looping here for new tags is acceptable as find_or_create_by_name is robust.
      # If performance for *brand new* tags in bulk was paramount and Tag model was simpler,
      # insert_all could be an option, but find_or_create_by_name is safer with existing model logic.
      new_tag_names.each do |name|
        # Tag.find_or_create_by_name already handles the downcasing and finding/creating logic.
        # This ensures that even if multiple new tags are processed concurrently,
        # uniqueness constraints are respected.
        created_tags << Tag.find_or_create_by_name(name)
      end
    end

    # Assign all relevant tags (existing + newly created) to the memo.
    # Rails will manage the join table records (creating new ones, deleting old ones).
    memo.tags = existing_tags + created_tags
  end

  # It seems this controller was using params[:tags] directly in some places,
  # and process_tags expects a string. Consolidating to use a 'tags_string' parameter
  # from forms is a good practice.
  # The 'add_memo' and 'create' actions were updated to look for
  # params.dig(:memo, :tags_string) or params[:tags_string].
  # The memo_params now also permits :tags_string.
  # The process_tags method now takes tag_names_string.
  # This makes tag handling more consistent.

  # Stub actions for routes defined but not yet implemented
  def toggle_visibility
    # TODO: Implement visibility toggle logic for @selected memo
    # Needs to be authorized by authorize_memo_owner_for_write
    # For now, redirect back or show error
    set_memo
    authorize_memo_owner_for_write
    # @selected.toggle!(:visibility) or similar logic
    flash[:notice] = "Visibility toggle not yet implemented for '#{@selected.title}'."
    redirect_to memo_path(@selected)
  end

  def share
    # TODO: Implement sharing logic for @selected memo
    # Needs to be authorized by authorize_memo_owner_for_write or specific sharing permission
    # For now, redirect back or show error
    set_memo
    authorize_memo_owner_for_write # Or a different authorization for sharing
    flash[:notice] = "Sharing not yet implemented for '#{@selected.title}'."
    redirect_to memo_path(@selected)
  end

  def public_memos
    # TODO: Implement listing of public memos from all users
    # May need pagination
    @user = current_user # For layout consistency
    @memo_new = current_user.memos.build # For layout consistency
    @memos = Memo.where(visibility: :public_memo).includes(:user, :tags).recent.page(params[:page])
    @tags = Memo.where(visibility: :public_memo).joins(:tags).group('tags.name').count
    flash.now[:notice] = "Listing all public memos." # Temporary message
    render :index # Re-use index view for listing, might need dedicated view later
  end

  def shared_memos
    # TODO: Implement listing of memos shared with current_user
    # This requires a sharing mechanism (e.g., through a join table)
    @user = current_user # For layout consistency
    @memo_new = current_user.memos.build # For layout consistency
    # @memos = current_user.shared_with_me_memos.includes(:user, :tags).recent.page(params[:page]) # Example
    @memos = current_user.memos.none.page(params[:page]) # Placeholder for no shared memos yet
    @tags = current_user.memos.none.joins(:tags).group('tags.name').count # Placeholder
    flash.now[:notice] = "Shared memos functionality not yet implemented."
    render :index # Re-use index view, might need dedicated view
  end
end
