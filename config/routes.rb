Rails.application.routes.draw do
  resources :users
  root "users#new"
  get "up" => "rails/health#show", as: :rails_health_check
  
end