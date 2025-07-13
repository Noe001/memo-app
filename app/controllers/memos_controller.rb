class MemosController < ApplicationController
  before_action :authenticate_user!
  # `set_memo` now fetches any memo, authorization is done separately.
  before_action :set_memo, only: [:show, :update, :destroy, :add_memo, :toggle_visibility, :share]
  before_action :authorize_memo_owner_for_write, only: [:update, :destroy, :toggle_visibility, :share]
  before_action :authorize_memo_for_read, only: [:show, :add_memo]

  def index
    prepare_index_data
  end

  def show
    # @memo is set by set_memo and authorized by authorize_memo_for_read
    if @memo.user_id != current_user_model.id
      @can_add_memo = true
      @new_memo_for_current_user = current_user_model.memos.build(
        title: @memo.title,
        description: @memo.description,
        visibility: :private_memo
      )
    else
      @can_add_memo = false
    end
    render :show
  end

  def add_memo
    # @memo is the source memo, authorized by authorize_memo_for_read
    result = MemoCopier.new(@memo, current_user_model, memo_params_for_add_memo).call

    if result.success?
      redirect_to memo_path(result.memo), notice: 'メモをあなたのリストに追加しました。'
    else
      flash.now[:alert] = "メモの追加に失敗しました: #{result.memo.errors.full_messages.join(', ')}"
      @can_add_memo = true
      @new_memo_for_current_user = result.memo
      render :show, status: :unprocessable_entity
    end
  end

    def create
    @memo_new = current_user_model.memos.build(memo_params)
    
    handle_tag_only_memo(@memo_new, memo_params[:tags_string])

    if @memo_new.save
      clear_temp_title_if_needed(@memo_new)
      
      # リアルタイム更新用のデータを準備
      prepare_index_data
      @memo = @memo_new
      
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
    memo_attributes = memo_params
    handle_tag_only_memo(@memo, memo_attributes[:tags_string])
    
    if @memo.update(memo_attributes)
      clear_temp_title_if_needed(@memo)
      
      # リアルタイム更新用のデータを準備
      prepare_index_data
      
      respond_to do |format|
        format.html { redirect_to memo_path(@memo), notice: 'メモを更新しました' }
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
    if @memo.destroy
      redirect_to root_path, notice: 'メモを削除しました'
    else
      redirect_to memo_path(@memo), alert: 'メモの削除に失敗しました'
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

    @memos = scope.apply_sort(@current_sort_by, @current_direction).page(params[:page])

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
    @memos = memo_scope.includes(:tags, :user).apply_sort(@current_sort_by, @current_direction).page(params[:page])
    # 総メモ数が存在するかどうかを事前に保持（検索結果の UI 用）
    @total_memos_exist = memo_scope.exists?
    @tags = memo_scope.joins(:tags).group('tags.name').count
  end

  def set_memo
    @memo = Memo.includes(:user, :tags).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to root_path, alert: '指定されたメモが見つかりません。' }
      format.json { render json: { status: 'error', message: '指定されたメモが見つかりません。' }, status: :not_found }
    end
  end

  def authorize_memo_owner_for_write
    authorize_owner!(@memo, message: 'このメモを編集または削除する権限がありません。')
  end

  def authorize_memo_for_read
    return if @memo.viewable_by?(current_user_model)
    
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'このメモを閲覧する権限がありません。' }
      format.json { render json: { status: 'error', message: 'このメモを閲覧する権限がありません。' }, status: :forbidden }
    end
  end

  def memo_params
    params.require(:memo).permit(:title, :description, :visibility, :tags_string, :group_id)
  end

  def memo_params_for_add_memo
    # For security, only permit attributes that are safe to copy.
    params.require(:memo).permit(:title, :description, :visibility, :tags_string)
  end

  def handle_tag_only_memo(memo, tags_string)
    return if tags_string.blank?
    if memo.title.blank? && memo.description.blank?
      memo.title = "無題"
    end
  end

  def clear_temp_title_if_needed(memo)
    # This needs to be called after save, so it should be in the successful save branch
    if memo.title == "無題" && memo.description.blank? && memo.tags.any?
      memo.update_column(:title, nil)
    end
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
    if @memo.toggle_visibility!
      redirect_to memo_path(@memo), notice: 'メモの公開状態を切り替えました。'
    else
      redirect_to memo_path(@memo), alert: '公開状態の切り替えに失敗しました。'
    end
  end

  def share
    # This is protected by authorize_memo_owner_for_write via before_action
    @user_groups = current_user_model.all_groups
    render :share
  end

  def public_memos
    @user = current_user # For layout consistency
    # Set up variables for the index view
    @memo_new = current_user_model.memos.build

    memo_scope = Memo.public_memo.includes(:user, :tags)

    @sort_options = Memo.sort_options
    @current_sort_by = params[:sort_by] || 'updated_at'
    @current_direction = params[:direction] || 'desc'

    @memos = memo_scope.apply_sort(@current_sort_by, @current_direction).page(params[:page])
    @total_memos_exist = memo_scope.exists?
    @tags = memo_scope.joins(:tags).group('tags.name').count

    # We can add a specific title for this page
    @page_title = "公開メモ"

    render :index
  end

  def shared_memos
    @user = current_user
    @memo_new = current_user_model.memos.build

    # Get all groups the user is part of, then find all 'shared' memos in those groups.
    user_group_ids = current_user_model.all_groups.pluck(:id)
    memo_scope = Memo.shared.where(group_id: user_group_ids).includes(:user, :tags, :group)

    @sort_options = Memo.sort_options
    @current_sort_by = params[:sort_by] || 'updated_at'
    @current_direction = params[:direction] || 'desc'

    @memos = memo_scope.apply_sort(@current_sort_by, @current_direction).page(params[:page])
    @total_memos_exist = memo_scope.exists?
    @tags = memo_scope.joins(:tags).group('tags.name').count

    @page_title = "共有されたメモ"

    render :index
  end
end
