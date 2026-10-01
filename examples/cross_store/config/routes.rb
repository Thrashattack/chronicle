Rails.application.routes.draw do
  resources :purchases, only: %i[index new create]
  root "purchases#index"
end
