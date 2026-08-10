Rails.application.routes.draw do
  get "/up", to: "rails/health#show"

  namespace :api do
    namespace :v1 do
      get :health, to: "health#show"

      namespace :auth do
        post :register, to: "registrations#create"
        post :login, to: "sessions#create"
        post :refresh, to: "refresh#create"
        post :logout, to: "logout#create"
      end

      resources :uploads, only: [ :create ]
    end
  end
end
