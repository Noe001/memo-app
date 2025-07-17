Rails.application.routes.draw do
  # ルートパス: 最新メモを表示
  root to: "memos#latest"
  
  # 認証関連（統一されたAuthController）
  scope '/auth' do
    get '/', to: 'auth#new', as: 'login'
    post '/login', to: 'auth#login'
    post '/signup', to: 'auth#signup'
    delete '/logout', to: 'auth#logout'
    post '/refresh_token', to: 'auth#refresh_token'
    get '/current_user_info', to: 'auth#current_user_info'
  end
  
  # レガシー互換性（段階的移行のため）
  get 'signup', to: 'auth#new'
  post 'signup', to: 'auth#signup'
  
  # ユーザー管理
  resources :users, only: [:show, :edit, :update, :create] do
    member do
      get :profile
    end
  end
  
  # 設定
  resource :settings, only: [:show, :update]
  
  # グループ関連（シンプル化）
  resources :groups do
    resources :invitations, only: [:create, :destroy], controller: 'groups/invitations'
    
    member do
      post :switch_to
      delete 'members/:user_id', to: 'groups/members#destroy', as: 'remove_member'
    end
  end
  
  # 招待承認
  get 'invitations/accept', to: 'invitations#accept', as: 'accept_invitation'
  
  # メモ関連
  resources :memos do
    member do
      post :add_memo
      patch :toggle_visibility
      get :share
    end
    
    collection do
      get :search
      get :public_memos
      get :shared_memos
    end
  end
  
  # タグ関連
  resources :tags, only: [:index, :show, :create, :update, :destroy] do
    resources :memos, only: [:index], controller: 'tags/memos'
  end
  
  # API v2（Supabase統合版のみ）
  namespace :api do
    namespace :v2 do
      resources :memos, except: [:new, :edit] do
        collection do
          get :search
          get :public_memos
        end
      end
      
      resources :tags, except: [:new, :edit]
      
      resources :groups, except: [:new, :edit] do
        resources :invitations, only: [:create, :destroy], controller: 'groups/invitations'
        member do
          post :switch_to
        end
      end
      
      resource :user, only: [:show, :update]
      
      # API認証
      post 'auth/login', to: 'sessions#create'
      delete 'auth/logout', to: 'sessions#destroy'
    end
  end
  
  # エラーハンドリング
  match '/404', to: 'errors#not_found', via: :all, as: 'not_found'
  match '/422', to: 'errors#unprocessable_entity', via: :all, as: 'unprocessable_entity'
  match '/500', to: 'errors#internal_server_error', via: :all, as: 'internal_server_error'
  
  # 未定義のルートをエラーページに転送
  match '*path', to: 'errors#not_found', via: :all
end
