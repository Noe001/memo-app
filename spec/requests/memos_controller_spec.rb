# spec/controllers/memos_controller_spec.rb
require 'rails_helper'

RSpec.describe MemosController, type: :controller do
  let!(:user) { FactoryBot.create(:user) } # FactoryBotを使用している場合
  let!(:memo) { FactoryBot.create(:memo, user: user) }

  def login_as(user)
    # セッションやコokiesを使用してユーザーを認証状態にする
    session[:user_id] = user.id
    cookies[:auth_token] = user.auth_token
  end

  describe "GET #index" do
    it "ログインしてルートパスにリダイレクトする" do
      user = FactoryBot.create(:user)
      login_as(user) # ログイン状態にする
      get :index
      expect(response).to redirect_to(home_index_path)
    end

    it "indexテンプレートをレンダリングする" do
      user = FactoryBot.create(:user)
      get :index
      expect(response).to render_template("index")
    end

    it "@memosにすべてのメモを割り当てる" do
      get :index
      expect(assigns(:memos)).to match_array([memo])
    end
  end

  describe "GET #show" do
    it "詳細ページをレンダリングする" do
      get :show, params: { id: memo.to_param }
      expect(response).to render_template("show")
    end

    it "@memoに要求されたメモを割り当てる" do
      get :show, params: { id: memo.to_param }
      expect(assigns(:memo)).to eq(memo)
    end
  end

  describe "POST #create" do
    context "有効なパラメータがある場合" do
      it "新しいメモを作成する" do
        expect {
          post :create, params: { memo: { title: "テストタイトル", description: "テスト内容" } }
        }.to change(Memo, :count).by(1)
      end

      it "一覧ページにリダイレクトする" do
        post :create, params: { memo: { title: "テストタイトル", description: "テスト内容" } }
        expect(response).to redirect_to(index_url)
      end
    end

    context "無効なパラメータがある場合" do
      it "新しいメモを保存しない" do
        expect {
          post :create, params: { memo: { title: "", description: "" } }
        }.not_to change(Memo, :count)
      end

      it "新規作成ページを再描画する" do
        post :create, params: { memo: { title: "", description: "" } }
        expect(response).to render_template("new")
      end
    end
  end

  describe "PATCH #update" do
    context "有効なパラメータがある場合" do
      before { patch :update, params: { id: memo.to_param, memo: { title: "更新済みタイトル", description: "更新済み内容" } } }

      it "要求されたメモを更新する" do
        expect(memo.reload.title).to eq("更新済みタイトル")
        expect(memo.reload.description).to eq("更新済み内容")
      end

      it "メモページにリダイレクトする" do
        expect(response).to redirect_to(memo_url(memo))
      end
    end

    context "無効なパラメータがある場合" do
      it "メモを更新しない" do
        patch :update, params: { id: memo.id, memo: { title: "", description: "" } }
        expect(memo.reload.title).not_to eq("")
        expect(memo.reload.description).not_to eq("")
      end

      it "編集ページを再描画する" do
        patch :update, params: { id: memo.id, memo: { title: "", description: "" } }
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE #destroy" do
    it "要求されたメモを削除する" do
      expect {
        delete :destroy, params: { id: memo.to_param }
      }.to change(Memo, :count).by(-1)
    end

    it "メモ一覧ページにリダイレクトする" do
      delete :destroy, params: { id: memo.to_param }
      expect(response).to redirect_to(index_url)
    end
  end
end
