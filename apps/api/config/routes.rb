Rails.application.routes.draw do
  get "/up", to: "rails/health#show"

  namespace :api do
    namespace :v1 do
      get :health, to: "health#show"
    end
  end
end