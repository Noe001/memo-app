Rails.application.routes.draw do

  get '/', to: redirect('/memos/0')
  get 'signup', to: 'users#signup', as: 'signup'
  post 'signup', to: 'users#create'
  resources :users, only: [:signup, :create]
  get 'login', to: 'sessions#new', as: 'new_sessions'
  post 'login', to: 'sessions#create', as: 'create_sessions'
  delete 'login', to: 'sessions#destroy', as: 'destroy_sessions'
  resources :memos, only: [:index, :update, :destroy, :create]
  get 'memos/:id', to: 'memos#index', as: 'selected_memo'
  get 'memos/:id/search', to: 'memos#search', as: 'search'
end
