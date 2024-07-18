require 'rails_helper'

RSpec.describe "Users", type: :request do
  describe "GET #signup" do
    it "assigns a new user to @user" do
      get :signup
      expect(assigns(:user)).to be_a_new(User)
    end
  end

  describe "POST #create" do
    context "with valid parameters" do
      it "creates a new User" do
        expect {
          post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'password' } }
        }.to change(User, :count).by(1)
      end

      it "redirects to the new session path" do
        post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'password' } }
        expect(response).to redirect_to(new_sessions_path)
      end
    end

    context "with invalid parameters" do
      it "does not save the new user" do
        expect {
          post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'wrong_password' } }
        }.not_to change(User, :count)
      end

      it "renders the signup page" do
        post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'wrong_password' } }
        expect(response).to render_template(:signup)
      end

      it "sets flash alert for password confirmation mismatch" do
        post :create, params: { user: { name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'wrong_password' } }
        expect(flash.now[:alert]).to eq('パスワードが一致しません')
      end

      it "sets flash alert for email already taken" do
        create(:user, email: 'existing@example.com') # Assuming you have FactoryBot setup
        post :create, params: { user: { name: 'Test User', email: 'existing@example.com', password: 'password', password_confirmation: 'password' } }
        expect(flash.now[:alert]).to eq('入力したメールアドレスは既に存在します')
      end
    end
  end
end
