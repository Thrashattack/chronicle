Rails.application.routes.draw do
  resources :animals, only: %i[index show new create] do
    post :locations, on: :member
  end
  root "animals#index"
end
