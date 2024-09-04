Rails.application.routes.draw do
  resources :users
  get "up" => "rails/health#show", as: :rails_health_check
  
end