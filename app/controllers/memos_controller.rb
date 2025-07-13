class MemosController < ApplicationController
  before_action :authenticate_user!
  # `set_memo` now fetches any memo, authorization is done separately.
  before_action :set_memo, only: [:show, :update, :destroy, :add_memo] # add_memo uses @selected
  before_action :authorize_memo_owner_for_write, only: [:update, :destroy]
  before_action :authorize_memo_for_read, only: [:show] # New authorization for show

  def index
    prepare_index_data
    
    # Removed logic that loaded a specific @selected memo by params[:id] in index.
    # Details of a specific memo should be viewed via the `show` action.
  end

  def show
    # @selected is set by set_memo and authorized by authorize_memo_for_read
    # The following lines seem to be for re-rendering index's list part,
    # which might be confusing if show is meant to display only one memo.
    # Consider a dedicated view for `show` or simplifying.
    prepare_index_data

    # Logic for "add this memo to my list" (if @selected is viewable and not owned)
    if @selected.user_id != current_user_model.id # Check if the selected memo is not owned by current user
      @can_add_selected_memo = true # Flag to show "add to my memos" button
      @memo_to_add = current_user_model.memos.build(
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
    # Ensure the memo exists and current user can read it
    set_memo
    authorize_memo_for_read
    
    # Additional check in case authorize_memo_for_read doesn't redirect (defensive programming)
    unless can_read_memo?(@selected, current_user_model)
      redirect_to root_path, alert: 'このメモを閲覧または追加する権限がありません。'
      return
    end

    # Build the new memo for the current user, copying content from @selected.
    @memo_to_add_to_own_list = current_user_model.memos.build(
      title: @selected.title,
      description: @selected.description,
      visibility: memo_params[:visibility] || :private_memo # User can choose visibility for their copy
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
      prepare_index_data
      if @selected.user_id != current_user_model.id
        @can_add_selected_memo = true
        # Rebuild @memo_to_add with submitted params if they exist, else from @selected
        # This assumes memo_params_for_add might be submitted via a form for add_memo
        submitted_title = params.dig(:memo, :title) || @selected.title
        submitted_description = params.dig(:memo, :description) || @selected.description
        submitted_visibility = params.dig(:memo, :visibility) || :private_memo

        @memo_to_add = current_user_model.memos.build(
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
    @memo_new = current_user_model.memos.build(memo_params)
    
    # タグがある場合は、タイトルと説明文が空でも保存を許可
    if @memo_new.title.blank? && @memo_new.description.blank? && params[:tags].present?
      @memo_new.title = "無題" # 一時的なタイトルを設定
    end
    
    if @memo_new.save
      # リスト重複防止のため最新の@memos等を取得
      prepare_index_data
      process_tags(@memo_new, params[:tags]) if params[:tags].present?
      
      # タグだけの場合は、一時的なタイトルを削除
      if @memo_new.title == "無題" && @memo_new.description.blank? && params[:tags].present?
        @memo_new.update_column(:title, nil)
      end
      
      # リアルタイム更新用のデータを準備
      prepare_index_data
      @selected = @memo_new
      
      respond_to do |format|
        format.html { redirect_to memo_path(@memo_new), notice: 'メモを作成しました' }
        format.turbo_stream
        format.json { render json: { status: 'success', message: 'メモを作成しました', memo_id: @memo_new.id }, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          prepare_index_data
          flash.now[:alert] = 'メモの保存に失敗しました'
          render :index
        end
        format.turbo_stream
        format.json { render json: { status: 'error', message: 'メモの保存に失敗しました', errors: @memo_new.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

    def update
    # タグがある場合は、タイトルと説明文が空でも保存を許可
    memo_attributes = memo_params
    if memo_attributes[:title].blank? && memo_attributes[:description].blank? && params[:tags].present?
      memo_attributes[:title] = "無題" # 一時的なタイトルを設定
      temp_title_set = true
    end
    
    if @selected.update(memo_attributes)
      process_tags(@selected, params[:tags]) if params[:tags].present?
      
      # タグだけの場合は、一時的なタイトルを削除
      if temp_title_set && @selected.description.blank? && params[:tags].present?
        @selected.update_column(:title, nil)
      end
      
      # リアルタイム更新用のデータを準備
      prepare_index_data
      
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), notice: 'メモを更新しました' }
        format.turbo_stream
        format.json { render json: { status: 'success', message: 'メモを更新しました' } }
      end
    else
      respond_to do |format|
        format.html do
          prepare_index_data
          flash.now[:alert] = 'メモの更新に失敗しました'
          render :index
        end
        format.turbo_stream
        format.json { render json: { status: 'error', message: 'メモの更新に失敗しました', errors: @selected.errors.full_messages } }
      end
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
    prepare_index_data

    search_word = params[:word]
    selected_tags = params[:tags] || []
    # params[:tags] は文字列または配列の可能性がある
    selected_tags = selected_tags.is_a?(Array) ? selected_tags : selected_tags.to_s.split(',')
    selected_tags.map!(&:strip)

    # グループに応じた検索範囲を設定
    if @current_group
      scope = @current_group.memos.accessible_by(current_user_model).includes(:tags, :user)
    else
      scope = current_user_model.memos.personal.includes(:tags)
    end
    
    scope = scope.search(search_word) if search_word.present?
    scope = scope.with_tags(selected_tags) if selected_tags.present?

    @memos = scope.distinct.apply_sort(@current_sort_by, @current_direction).page(params[:page])

    # 選択タグはビューでハイライトするために保持
    @selected_tags = selected_tags

    # 総メモ数が存在するかどうかを事前に保持（検索結果の UI 用）
    @total_memos_exist = scope.exists?

    # 空検索結果時の UI はビューで判定・表示する（フラッシュではなくメモリスト内で表示）

    respond_to do |format|
      format.html { render :index }
      format.turbo_stream # search.turbo_stream.erb をレンダリング
    end
  end

  # ルートパスから呼ばれ、最新のメモを表示する
  def latest
    # 認証チェック
    unless current_user
      redirect_to auth_login_path, alert: 'ログインしてください'
      return
    end

    # current_user_modelがnilの場合の対応
    user_model = current_user_model
    unless user_model
      Rails.logger.error "current_user_model is nil for user: #{current_user&.email}"
      redirect_to auth_login_path, alert: 'ユーザー情報の取得に失敗しました。再度ログインしてください。'
      return
    end

    # ユーザーの最新更新メモを取得
    latest_memo = user_model.memos.recent.first

    if latest_memo
      # 既存の show ビュー/ロジックを流用するためリダイレクト
      redirect_to memo_path(latest_memo)
    else
      # メモがない場合は一覧ページ（新規作成フォーム付き）を表示
      prepare_index_data
      render :index
    end
  end

  private

  def prepare_index_data
    @user = current_user
    
    # current_user_modelがnilの場合の対応
    user_model = current_user_model
    unless user_model
      Rails.logger.error "current_user_model is nil in prepare_index_data for user: #{current_user&.email}"
      # デフォルト値を設定してエラーを回避
      @memo_new = Memo.new
      @sort_options = Memo.sort_options
      @current_sort_by = params[:sort_by] || 'updated_at'
      @current_direction = params[:direction] || 'desc'
      @memos = Memo.none.page(params[:page])
      @total_memos_exist = false
      @tags = {}
      @current_group = nil
      @user_groups = []
      return
    end
    
    # グループ関連の設定
    @current_group = session[:current_group_id] ? Group.find_by(id: session[:current_group_id]) : nil
    @user_groups = user_model.all_groups.includes(:owner, :users)
    
    # メモの取得範囲を決定
    if @current_group
      # グループが選択されている場合はグループのメモのみ
      memo_scope = @current_group.memos.accessible_by(user_model)
      @memo_new = @current_group.memos.build(user: user_model) unless @memo_new&.persisted?
    else
      # グループが選択されていない場合は個人のメモのみ
      memo_scope = user_model.memos.personal
      @memo_new = user_model.memos.build unless @memo_new&.persisted?
    end
    
    @sort_options = Memo.sort_options
    @current_sort_by = params[:sort_by] || 'updated_at'
    @current_direction = params[:direction] || 'desc'
    @memos = memo_scope.includes(:tags, :user).distinct.apply_sort(@current_sort_by, @current_direction).page(params[:page])
    # 総メモ数が存在するかどうかを事前に保持（検索結果の UI 用）
    @total_memos_exist = memo_scope.exists?
    @tags = memo_scope.joins(:tags).group('tags.name').count
  end

  def set_memo
    # Fetches any memo by ID, includes associations for efficiency.
    # Authorization is handled by separate before_actions.
    @selected = Memo.includes(:user, :tags).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to root_path, alert: '指定されたメモが見つかりません。' }
      format.json { render json: { status: 'error', message: '指定されたメモが見つかりません。' }, status: :not_found }
    end
  end

  # For write actions (update, destroy)
  def authorize_memo_owner_for_write
    return if @selected&.user_id == current_user_model&.id
    
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'このメモを編集または削除する権限がありません。' }
      format.json { render json: { status: 'error', message: 'このメモを編集または削除する権限がありません。' }, status: :forbidden }
    end
  end

  # For read actions (show, potentially add_memo's source)
  def authorize_memo_for_read
    return if can_read_memo?(@selected, current_user_model)
    
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'このメモを閲覧する権限がありません。' }
      format.json { render json: { status: 'error', message: 'このメモを閲覧する権限がありません。' }, status: :forbidden }
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
    params.require(:memo).permit(:title, :description, :visibility, :tags_string, :group_id)
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
    set_memo
    authorize_memo_owner_for_write
    
    new_visibility = @selected.public_memo? ? :private_memo : :public_memo
    if @selected.update(visibility: new_visibility)
      message = @selected.public_memo? ? 
        "メモを公開しました" : "メモを非公開にしました"
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), notice: message }
        format.turbo_stream { flash.now[:notice] = message }
      end
    else
      message = "可視性の変更に失敗しました: #{@selected.errors.full_messages.join(', ')}"
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), alert: message }
        format.turbo_stream { flash.now[:alert] = message }
      end
    end
  end

  def share
    set_memo
    authorize_memo_owner_for_write
    
    # 共有先ユーザーIDを取得
    user_id = params[:user_id]
    permission_level = params[:permission_level] || 'read'
    
    # ユーザー存在チェック
    target_user = User.find_by(id: user_id)
    unless target_user
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), alert: '共有先ユーザーが見つかりません' }
        format.turbo_stream { flash.now[:alert] = '共有先ユーザーが見つかりません' }
      end
      return
    end
    
    # 自分自身への共有は許可しない
    if target_user.id == current_user_model.id
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), alert: '自分自身には共有できません' }
        format.turbo_stream { flash.now[:alert] = '自分自身には共有できません' }
      end
      return
    end
    
    # 既に共有済みかチェック
    existing_share = @selected.shares.find_by(user_id: target_user.id)
    if existing_share
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), alert: 'このユーザーには既に共有済みです' }
        format.turbo_stream { flash.now[:alert] = 'このユーザーには既に共有済みです' }
      end
      return
    end
    
    # 共有を作成
    share = @selected.shares.build(
      user_id: target_user.id,
      permission_level: permission_level
    )
    
    if share.save
      message = "#{target_user.name}さんとメモを共有しました（権限: #{share.permission_level == 'read' ? '閲覧' : '編集'}）"
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), notice: message }
        format.turbo_stream { flash.now[:notice] = message }
      end
    else
      message = "共有に失敗しました: #{share.errors.full_messages.join(', ')}"
      respond_to do |format|
        format.html { redirect_to memo_path(@selected), alert: message }
        format.turbo_stream { flash.now[:alert] = message }
      end
    end
  end

  def public_memos
    @user = current_user
    @memo_new = current_user_model.memos.build
    
    # 検索条件の取得
    search_word = params[:word]
    selected_tags = params[:tags] || []
    selected_tags = selected_tags.is_a?(Array) ? selected_tags : selected_tags.to_s.split(',')
    selected_tags.map!(&:strip)
    
    # 公開メモの取得
    scope = Memo.where(visibility: :public_memo).includes(:user, :tags)
    scope = scope.search(search_word) if search_word.present?
    scope = scope.with_tags(selected_tags) if selected_tags.present?
    
    # ソート設定
    @sort_options = Memo.sort_options
    @current_sort_by = params[:sort_by] || 'updated_at'
    @current_direction = params[:direction] || 'desc'
    
    @memos = scope.distinct.apply_sort(@current_sort_by, @current_direction).page(params[:page])
    @tags = scope.joins(:tags).group('tags.name').count
    @selected_tags = selected_tags
    @total_memos_exist = scope.exists?
    
    # グループ関連の変数を空に設定（ナビゲーション用）
    @current_group = nil
    @user_groups = current_user_model.all_groups.includes(:owner, :users) if current_user_model
    
    render :index
  end

  def shared_memos
    @user = current_user
    @memo_new = current_user_model.memos.build
    
    # 検索条件の取得
    search_word = params[:word]
    selected_tags = params[:tags] || []
    selected_tags = selected_tags.is_a?(Array) ? selected_tags : selected_tags.to_s.split(',')
    selected_tags.map!(&:strip)
    
    # 共有メモの取得 (user_idが自分ではないメモで、かつ共有されているもの)
    scope = Memo.joins(:shares)
                .where(shares: { user_id: current_user_model.id })
                .where.not(user_id: current_user_model.id)
                .includes(:user, :tags)
    
    scope = scope.search(search_word) if search_word.present?
    scope = scope.with_tags(selected_tags) if selected_tags.present?
    
    # ソート設定
    @sort_options = Memo.sort_options
    @current_sort_by = params[:sort_by] || 'updated_at'
    @current_direction = params[:direction] || 'desc'
    
    @memos = scope.distinct.apply_sort(@current_sort_by, @current_direction).page(params[:page])
    @tags = scope.joins(:tags).group('tags.name').count
    @selected_tags = selected_tags
    @total_memos_exist = scope.exists?
    
    # グループ関連の変数を空に設定（ナビゲーション用）
    @current_group = nil
    @user_groups = current_user_model.all_groups.includes(:owner, :users) if current_user_model
    
    render :index
  end
end
