class MemosController < ApplicationController
  before_action :current_user
  before_action :set_memo, only: [:show, :update, :destroy]

  def index
    # createメソッドで使用
    @memo_new = Memo.new
    # ログインしてるユーザーが作成したメモ（サイドバーで使用）
    @memos = current_user.memos
    if params[:id]
      # サイドバーで選択またはURLで入力したメモ（フォーム表示に使用）
      @selected = Memo.find(params[:id])
      # メモをシェアした際にシェア元のユーザー名を表示
      @memo_id = params[:id]
      # 一覧から選択したコンテンツの背景を変えるために使用
      @shared_user = @selected.user.name
      # trueかfalseを代入
      @can_add = @selected.user_id != current_user.id
      @memo_to_add = current_user.memos.new(title: @selected.title, description: @selected.description)
    end
  end

  def show
    @memo_new = Memo.new
    @memos = current_user.memos
    @can_add = @selected.user_id != current_user.id
    @shared_user = @selected.user.name
    @memo_id = @selected.id
    @memo_to_add = current_user.memos.new(title: @selected.title, description: @selected.description)
    render :index
  end

  def add_memo
    @memo_to_add = current_user.memos.new(memos_params)
    if @memo_to_add.save
      if @memo_to_add.title.blank? && @memo_to_add.description.blank?
        @memo_to_add.destroy
        redirect_to root_path, notice: '未入力だったため追加されませんでした'
      else
        redirect_to memo_path(@memo_to_add), notice: 'リストに追加しました'
      end
    else
      @memos = current_user.memos
      @selected = Memo.find(params[:id])
      @can_add = true
      flash.now[:alert] = '追加に失敗しました'
      render :index
    end
  end

  def create
    # ログインしたユーザーに関連付けられたメモを作成
    @memo_new = current_user.memos.build(memos_params)
    if @memo_new.save
      # タイトルと本文が空の場合はメモを削除
      if @memo_new.title.blank? && @memo_new.description.blank?
        @memo_new.destroy
        flash[alert:] = 'タイトルと本文を入力してください'
      else
        flash[notice:] = '作成しました'
      end
      redirect_to memos_path
    else
      flash[alert:] = '保存に失敗しました'
      render :index
    end
  end

  def update
    if @selected.update(memos_params)
      if @selected.title.blank? && @selected.description.blank?
        @selected.destroy
        redirect_to root_path, notice: '未入力だったため削除されました'
      else
        redirect_to memo_path(@selected), notice: '更新しました'
      end
    else
      @memos = current_user.memos
      @memos_new = Memo.new
      flash.now[alert:] = '更新に失敗しました'
      render :index
    end
  end

  def destroy
    if @selected.destroy
      redirect_to root_path, notice: 'メモが削除されました'
    else
      redirect_to memo_path(@selected), alert: '削除に失敗しました'
    end
  end

  def search
    @memo_new = Memo.new
    search_word = params[:word]
    @memos = current_user.memos.where("title LIKE ? OR description LIKE ?", "%#{search_word}%", "%#{search_word}%")
    @selected = Memo.find_by(id: params[:id])
    if @memos.empty?
      flash.now[:alert] = "該当するメモは見つかりませんでした"
    end
    render :index
  end

  private

  def set_memo
    @selected = Memo.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: '指定されたメモが見つかりません'
  end

  def memos_params
    params.require(:memo).permit(:title, :description)
  end

  def current_user
    if session[:user_id]
      @user = User.find(session[:user_id])
    else
      redirect_to new_sessions_path
    end
  end
end
