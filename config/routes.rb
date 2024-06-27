Rails.application.routes.draw do
  
  get '/', to: redirect('/memos')
  get 'signup' to: 'users#signup', as: 'signup_users'
  post 'signup' to: 'users#create'. as: 'create_users'
  get 'login', to: 'sessions#new', as: 'new_sessions'
  post 'login', to: 'sessions#create', as: 'create_sessions'
  delete 'login', to: 'sessions#destroy', as: 'destroy_sessions'
  resources :memos, only: [:index, :update, :destroy, :create]
  get 'memos/:id' => 'memos#index', as: 'selected_memo'
  
end
