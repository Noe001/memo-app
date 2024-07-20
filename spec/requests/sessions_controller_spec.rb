require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:user) { create(:user) }

  before do
    post '/login', params: { session: { email: user.email, password: user.password } }
    session[:user_id] = user.id
  end

  describe 'GET #new' do
    context 'ユーザーがログインしていない場合' do
      it 'newテンプレートをレンダリングする' do
        get :new
        expect(response).to render_template(:new)
      end
    end

    context 'ユーザーが既にログインしている場合' do
      before { session[:user_id] = user.id }

      it 'ルートパスにリダイレクトする' do
        get :new
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('ログインしています')
      end
    end
  end

  describe 'POST #create' do
    context '有効な認証情報の場合' do
      it 'ユーザーをログインさせ、ルートパスにリダイレクトする' do
        post create_sessions_path, params: { session: { email: user.email, password: user.password } }
        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('ログインしました')
      end
    end

    context '無効な認証情報の場合' do
      it 'newテンプレートを再表示し、エラーメッセージを表示する' do
        post create_sessions_path, params: { session: { email: user.email, password: user.password } }
        expect(session[:user_id]).to be_nil
        expect(response).to render_template(:new)
        expect(flash[:alert]).to eq('メールアドレスまたはパスワードが無効です')
      end
    end

    context 'ユーザーが既にログインしている場合' do
      before { session[:user_id] = user.id }

      it 'ルートパスにリダイレクトする' do
        post create_sessions_path, params: { session: { email: user.email, password: user.password } }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('ログインし��います')
      end
    end
  end

  describe 'DELETE #destroy' do
    before { session[:user_id] = user.id }

    it 'ユーザーをログアウトさせ、新しいセッションパスにリダイレクトする' do
      delete :destroy
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(new_sessions_path)
      expect(flash[:notice]).to eq('ログアウトしました')
    end
  end
end
