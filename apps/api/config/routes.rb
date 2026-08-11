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
      resources :tickets, only: [ :index, :show ]
      get :dashboard, to: "dashboard#show"
      get :reports, to: "reports#index"
      scope :reports do
        resource :executive_summary, only: [ :show, :create ], path: "executive-summary", controller: "executive_summaries"
      end
    end
  end
end
