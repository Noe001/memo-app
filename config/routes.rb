Rails.application.routes.draw do

  root to: 'memos#index'
  get 'login', to: 'sessions#new', as: 'new_sessions'
  post 'login', to: 'sessions#create', as: 'create_sessions'
  delete 'login', to: 'sessions#destroy', as: 'destroy_sessions'
  resources :memos, only: [:index, :update, :destroy, :create]
  
end
