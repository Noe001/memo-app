Rails.application.routes.draw do
  # ルートパス: 最新メモを表示
  root to: "memos#latest"
  
  # 認証関連（新しいAuthController）
  scope '/auth' do
    get '/', to: 'auth#new', as: 'auth_login'
    post '/login', to: 'auth#login'
    post '/signup', to: 'auth#signup', as: 'auth_signup'
    delete '/logout', to: 'auth#logout'
    post '/refresh_token', to: 'auth#refresh_token'
    get '/current_user_info', to: 'auth#current_user_info'
  end
  
  # 認証関連（レガシーSessionsController - 段階的移行のため）
  resource :session, only: [:new, :create, :destroy], controller: 'sessions' do
    collection do
      delete :destroy_all  # 全セッション削除
    end
  end
  
  resources :users, only: [:show, :edit, :update, :create] do
    member do
      get :profile
    end
  end
  
  # 設定
  resource :settings, only: [:show, :update]
  
  # ユーザー登録（AuthControllerに統一）
  get 'signup', to: 'auth#new', as: 'signup'
  post 'signup', to: 'auth#signup'
  
  # ログイン関連のエイリアス（既存との互換性）
  get 'login', to: 'auth#new', as: 'new_sessions'
  post 'login', to: 'auth#login', as: 'create_sessions'
  delete 'login', to: 'auth#logout', as: 'destroy_sessions'
  
  # メモ関連
  resources :memos do
    member do
      post :add_memo
      patch :toggle_visibility
      get :share
    end
    
    collection do
      get :search
      get :public_memos  # 公開メモ一覧
      get :shared_memos  # 共有メモ一覧
    end
  end
  
  # タグ関連
  resources :tags, only: [:index, :show, :create, :update, :destroy] do
    resources :memos, only: [:index], controller: 'tags/memos'
  end
  
  # API
  namespace :api do
    namespace :v1 do
      resources :memos, except: [:new, :edit] do
        collection do
          get :search
        end
      end
      
      resources :tags, except: [:new, :edit]
      
      resource :user, only: [:show, :update] # This will need API auth using `authenticate_api_user!`
      
      # API Authentication routes
      # These will automatically map to Api::V1::SessionsController due to the namespace
      post 'auth/login', to: 'sessions#create'
      delete 'auth/logout', to: 'sessions#destroy'
    end
    
    # API v2 - Supabase統合
    namespace :v2 do
      resources :memos, except: [:new, :edit] do
        collection do
          get :search
          get :public_memos
        end
      end
      
      resources :tags, except: [:new, :edit]
      
      resource :user, only: [:show, :update]
    end
  end
  
  # 管理者機能（将来の拡張用）
  namespace :admin do
    resources :users, only: [:index, :show, :update, :destroy]
    resources :memos, only: [:index, :show, :destroy]
    resources :tags, only: [:index, :show, :update, :destroy]
    
    root to: 'dashboard#index'
  end
  
  # セキュリティ関連のルートを一時的に削除
  # post '/csp-violation-report-endpoint', to: 'security#csp_violation_report'
  
  # エラーハンドリング
  match '/404', to: 'errors#not_found', via: :all, as: 'not_found'
  match '/422', to: 'errors#unprocessable_entity', via: :all, as: 'unprocessable_entity'
  match '/500', to: 'errors#internal_server_error', via: :all, as: 'internal_server_error'
  
  # 未定義のルートをエラーページに転送
  match '*path', to: 'errors#not_found', via: :all
end
