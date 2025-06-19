class MemosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_memo, only: [:show, :update, :destroy]
  before_action :authorize_memo_owner, only: [:update, :destroy]

  def index
    @user = current_user  # ビューで使用するため追加
    @memo_new = current_user.memos.build
    @memos = current_user.memos.includes(:tags).recent.page(params[:page])
    @tags = current_user.memos.joins(:tags).includes(:tags).group('tags.name').count
    
    if params[:id]
      @selected = Memo.includes(:user, :tags).find(params[:id])
      @memo_id = params[:id]
      @shared_user = @selected.user.name
      @can_add = @selected.user_id != current_user.id
      @memo_to_add = current_user.memos.build(
        title: @selected.title, 
        description: @selected.description,
        visibility: :private_memo
      )
    end
  end

  def show
    @user = current_user  # ビューで使用するため追加
    @memo_new = current_user.memos.build
    @memos = current_user.memos.includes(:tags).recent.page(params[:page])
    @tags = current_user.memos.joins(:tags).includes(:tags).group('tags.name').count
    @can_add = @selected.user_id != current_user.id
    @shared_user = @selected.user.name
    @memo_id = @selected.id
    @memo_to_add = current_user.memos.build(
      title: @selected.title, 
      description: @selected.description,
      visibility: :private_memo
    )
    render :index
  end

  def add_memo
    @memo_to_add = current_user.memos.build(memo_params)
    
    if @memo_to_add.save
      process_tags(@memo_to_add, params[:tags]) if params[:tags].present?
      redirect_to memo_path(@memo_to_add), notice: 'メモをリストに追加しました'
    else
      @memos = current_user.memos.includes(:tags).recent.page(params[:page])
      @selected = Memo.includes(:user, :tags).find(params[:id])
      @can_add = true
      @tags = current_user.memos.joins(:tags).includes(:tags).group('tags.name').count
      flash.now[:alert] = 'メモの追加に失敗しました'
      render :index
    end
  end

  def create
    @memo_new = current_user.memos.build(memo_params)
    
    if @memo_new.save
      process_tags(@memo_new, params[:tags]) if params[:tags].present?
      redirect_to memo_path(@memo_new), notice: 'メモを作成しました'
    else
      @memos = current_user.memos.includes(:tags).recent.page(params[:page])
      @tags = current_user.memos.joins(:tags).includes(:tags).group('tags.name').count
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
      @tags = current_user.memos.joins(:tags).includes(:tags).group('tags.name').count
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
    @user = current_user  # ビューで使用するため追加
    @memo_new = current_user.memos.build
    search_word = params[:word]
    @memos = current_user.memos.includes(:tags).search(search_word).recent.page(params[:page])
    @tags = current_user.memos.joins(:tags).includes(:tags).group('tags.name').count
    @selected = Memo.includes(:user, :tags).find_by(id: params[:id])
    
    if @memos.empty?
      flash.now[:alert] = "「#{search_word}」に該当するメモは見つかりませんでした"
    end
    
    render :index
  end

  def export
    @memos = current_user.memos.includes(:tags)
    
    respond_to do |format|
      format.json { render json: @memos.to_json(include: :tags) }
      format.csv { send_data generate_csv(@memos), filename: "memos-#{Date.current}.csv" }
    end
  end

  private

  def set_memo
    @selected = Memo.includes(:user, :tags).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: '指定されたメモが見つかりません'
  end

  def authorize_memo_owner
    unless @selected.user == current_user
      redirect_to root_path, alert: 'このメモを編集する権限がありません'
    end
  end

  def memo_params
    params.require(:memo).permit(:title, :description, :visibility)
  end

  def process_tags(memo, tag_names)
    return if tag_names.blank?
    
    # 既存のタグを削除
    memo.memo_tags.destroy_all
    
    # 新しいタグを追加
    tag_names.split(',').each do |tag_name|
      tag = Tag.find_or_create_by_name(tag_name.strip)
      memo.memo_tags.create(tag: tag)
    end
  end

  def generate_csv(memos)
    CSV.generate do |csv|
      csv << ['ID', 'Title', 'Description', 'Tags', 'Created At', 'Updated At']
      memos.each do |memo|
        csv << [
          memo.id,
          memo.title,
          memo.description,
          memo.tags.pluck(:name).join(', '),
          memo.created_at,
          memo.updated_at
        ]
      end
    end
  end
end
