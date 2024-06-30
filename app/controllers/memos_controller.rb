class MemosController < ApplicationController
  before_action :current_user

  def index
    @memo_new = Memo.new
    @memos = current_user.memos
    @selected_memo = params[:id] && params[:id] != '0' ? Memo.find_by(id: params[:id]) : nil
  end

  def show
    @memo_new = Memo.new
    @memos = current_user.memos
    @selected_memo = current_user.memos.find(params[:id])
    render :index
  end

  def create
    @memo_new = current_user.memos.build(memos_params)
    if @memo_new.save
      if @memo_new.title.blank? && @memo_new.description.blank?
        @memo_new.destroy
        redirect_to memos_path, alert: 'タイトルと概要を入力してください'
      else
        redirect_to memos_path, notice: '作成しました'
      end
    else
      redirect_to memos_path, alert: '保存に失敗しました'
    end
  end

  def update
    @memo = current_user.memos.find(params[:id])
    if @memo.update(memos_params)
      if @memo.title.blank? && @memo.description.blank?
        @memo.destroy
        redirect_to memos_path, notice: '未入力だったため削除されました'
      else
        redirect_to memos_path, notice: '更新しました'
      end
    else
      redirect_to memos_path, alert: '更新に失敗しました'
    end
  end

  def destroy
    @memo = current_user.memos.find(params[:id])
    if @memo.destroy
      redirect_to memos_path, notice: 'メモが削除されました'
    else
      redirect_to memos_path, alert: '削除に失敗しました'
    end
  end

  def search
    @memo_new = Memo.new
    search_word = params[:word]
    @memos = current_user.memos.where("title LIKE ? OR description LIKE ?", "%#{search_word}%", "%#{search_word}%")
    @selected_memo = params[:id] && params[:id] != '0' ? Memo.find_by(id: params[:id]) : nil
    if @memos.empty?
      flash.now[:alert] = "該当するメモは見つかりませんでした"
    end
    render :index
  end

  private

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
