Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :registration, only: [ :new, :create, :show ]
  resource :registration_email, only: :create
  resource :registration_confirmation, only: [ :show, :create ]

  resource :password_reset, only: [ :new, :create, :edit, :update ]

  resource :guest_session, only: :create

  resource :session, only: [ :new, :create, :destroy ]

  resource :rating, only: [ :new, :create, :edit, :update ], controller: :ratings do
    post :dismiss
  end

  resource :account, only: :show, controller: :account do
    post :refresh_taste_profile
  end

  resource :recommendation, only: :show, controller: :recommendations do
    post :accept
    post :reject
  end

  post "library/from_ratings/watchlist", to: "library#add_to_watchlist_from_ratings", as: :add_to_watchlist_from_ratings
  post "library/from_recommendations/watched", to: "library#mark_watched_from_recommendations", as: :mark_watched_from_recommendations

  resource :library, only: :show, controller: :library

  get "library/films/:id", to: "library#film", as: :library_film
  post "library/films/:id/mark_watched", to: "library#mark_watched", as: :mark_watched_library_film
  delete "library/films/:id/remove_from_watchlist", to: "library#remove_from_watchlist", as: :remove_from_watchlist_library_film


  namespace :registry do
    root "films#index"
    resources :films, :quality_categories, :qualities, only: [ :index, :show ]
  end

  # Defines the root path route ("/")
  root "landing#show"
end
