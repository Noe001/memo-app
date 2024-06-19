class MemosController < ApplicationController
  # ユーザーがログインしていることを確認
  before_action :current_user

  def index
    @memo_new = Memo.new
    # ログインしたユーザーが作成したメモのみを取得
    @memos = current_user.memos
  end

  def create
    # ログインしたユーザーに関連付けられたメモを作成
    @memo_new = current_user.memos.build(memos_params)
    # データベースに保存しつつバリデーションが合格したかどうか判別
    if @memo_new.save
      redirect_to root_path, notice: 'メモが作成されました'
    else
      flash.now[:alert] = 'メモの作成に失敗しました。タイトルと説明を入力してください'
      # エラーがある場合は同じフォームを再表示
      render :new
    end
  end

  def update
    # メモの内容を更新
    @memo = current_user.memos.find(params[:id])
    if @memo.update(memos_params)
      redirect_to root_path, notice: 'メモが更新されました'
    else
      render :edit
    end
  end

  def destroy
    # メモを削除
    @memo = current_user.memos.find(params[:id])
    @memo.destroy
    redirect_to root_path, notice: 'メモが削除されました'
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