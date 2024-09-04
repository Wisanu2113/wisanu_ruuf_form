Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  
  resources :users, only: [:index, :new, :create, :edit, :update, :destroy]

end
