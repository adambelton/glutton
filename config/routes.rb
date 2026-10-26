Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :registration, only: [ :new, :create, :show ]
  resource :registration_email, only: :create
  resource :registration_confirmation, only: [ :show, :create ]

  resource :password_reset, only: [ :new, :create, :edit, :update ]

  resource :session, only: [ :new, :create, :destroy ]

  scope module: :ratings do
    resources :ratings, only: [ :new, :create ] do
      post :dismiss, on: :collection
    end
  end

  # Defines the root path route ("/")
  root "home#index"
end
