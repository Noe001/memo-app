require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe "GET #signup" do
    it "assigns a new user to @user" do
      get :signup
      expect(assigns(:user)).to be_a_new(User)
    end
  end

  describe "POST #create（新規ユーザー作成）" do
    context "有効なパラメータの場合" do
      it "新しいユーザーを作成する" do
        expect {
          post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'password' } }
        }.to change(User, :count).by(1)
      end

      it "新しいセッションパスにリダイレクトする" do
        post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'password' } }
        expect(response).to redirect_to(new_sessions_path)
      end
    end

    context "無効なパラメータの場合" do
      it "新しいユーザーを保存しない" do
        expect {
          post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'wrong_password' } }
        }.not_to change(User, :count)
      end

      it "サインアップページを再表示する" do
        post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'wrong_password' } }
        expect(response).to render_template(:signup)
      end

      it "パスワード確認の不一致に対してフラッシュアラートを設定する" do
        post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'wrong_password' } }
        expect(flash.now[:alert]).to eq('パスワードが一致しません')
      end

      it "既に存在するメールアドレスに対してフラッシュアラートを設定する" do
        create(:user, email: 'existing@example.com')
        post :create, params: { user: { name: 'Test User', email: 'existing@example.com', password: 'password', password_confirmation: 'password' } }
        expect(flash.now[:alert]).to eq('入力したメールアドレスは既に存在します')
      end
    end
  end
end
