Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "privacy", to: "privacy_notices#show", as: :privacy_notice
  get "terms", to: "terms_of_service#show", as: :terms_of_service
  get "community/code-of-conduct", to: "community/code_of_conduct#show", as: :community_code_of_conduct
  get "community", to: "community/board#show", as: :community
  post "community/code-of-conduct/acceptance", to: "community/code_of_conduct#accept", as: :community_code_of_conduct_acceptance
  scope :community, as: :community, module: :community do
    resource :moderation, only: :show, controller: :moderation
    resources :moderation_reports, path: "moderation/reports", only: :show do
      patch :escalate, on: :member
      patch :resolve, on: :member
    end
    resources :posts, only: [ :new, :create, :show, :edit, :update, :destroy ] do
      resource :report, only: [ :new, :create ], controller: :reports
      resources :comments, only: [ :create, :edit, :update, :destroy ], controller: :post_comments do
        resource :report, only: [ :new, :create ], controller: :reports
        get "reply/new", action: :new_reply, as: :new_reply, on: :member
        post :reply, action: :create_reply, on: :member
      end
      get :discussion, on: :member
    end

    scope "posts/:post_id", as: :curation do
      resource :endorsements, only: [ :edit, :update ], controller: :curation_endorsements
      patch "additional_description", to: "posts#additional_description"
      patch "disassociate", to: "posts#disassociate"
      post "films/:film_id/watchlist", to: "posts#watchlist", as: :film_watchlist
      post "films/:film_id/watched", to: "posts#watched", as: :film_watched
    end
  end

  resource :registration, only: [ :new, :create, :show ]
  resource :registration_email, only: :create
  resource :registration_confirmation, only: [ :show, :create ]

  resource :password_reset, only: [ :new, :create, :edit, :update ]

  resource :guest_session, only: [ :create, :destroy ]

  resource :session, only: [ :new, :create, :destroy ]

  resource :rating, only: [ :new, :create, :edit, :update ], controller: :ratings do
    post :dismiss
    get :choose_films
    post :queue_films
    post :surprise
  end

  get "account", to: redirect("/account/settings", status: 302), as: :account
  get "account/settings", to: "account_settings#show", as: :account_settings
  get "account/community", to: "account_settings#show_community", as: :account_community
  patch "account/community/username", to: "account_settings#change_community_username", as: :account_community_username
  patch "account/community/avatar", to: "account_settings#choose_community_avatar", as: :account_community_avatar
  get "account/taste-profile", to: "account#show", as: :account_taste_profile
  post "account/refresh_taste_profile", to: "account#refresh_taste_profile", as: :refresh_taste_profile_account
  post "account/email", to: "account_settings#request_email", as: :account_email
  get "account/email/confirm", to: "account_settings#show_email_confirmation", as: :confirm_account_email
  post "account/email/confirm", to: "account_settings#confirm_email"
  patch "account/password", to: "account_settings#change_password", as: :account_password
  delete "account", to: "account_settings#destroy"

  resource :recommendation, only: :show, controller: :recommendations do
    get :availability
    post :accept
    post :reject
  end

  post "library/from_ratings/watchlist", to: "library#add_to_watchlist_from_ratings", as: :add_to_watchlist_from_ratings
  post "library/from_recommendations/watched", to: "library#add_to_watched_from_recommendations", as: :add_to_watched_from_recommendations

  resource :library, only: :show, controller: :library
  get "library/search", to: "library/tmdb_film_search#index", as: :library_tmdb_film_search
  post "library/search/watchlist", to: "library/tmdb_film_search#add_to_watchlist", as: :library_tmdb_search_watchlist
  post "library/search/watched", to: "library/tmdb_film_search#add_to_watched", as: :library_tmdb_search_watched

  post "library/films/:id/move_to_watched", to: "library#move_to_watched", as: :move_to_watched_library_film
  post "library/films/:id/move_to_watchlist", to: "library#move_to_watchlist", as: :move_to_watchlist_library_film
  delete "library/films/:id/remove_from_watched", to: "library#remove_from_watched", as: :remove_from_watched_library_film
  delete "library/films/:id/remove_from_watchlist", to: "library#remove_from_watchlist", as: :remove_from_watchlist_library_film


  get "admin", to: "admin#show", as: :admin

  scope :admin, as: :admin do
    post "users", to: "identity/users#index"
    resources :users, only: [ :index, :show ], controller: "identity/users" do
      delete "sessions/:session_id", action: :revoke_session, as: :session, on: :member
      get "glutton-profile", to: "ratings/profile_inspections#show", as: :glutton_profile, on: :member
      resource :community_moderator_role, path: "community-moderator-role", only: [ :create, :destroy ],
        controller: "community/moderator_roles"
    end
    post "films", to: "registry/tmdb_film_search#create", as: :import_tmdb_film
    resources :films, only: [ :index, :show ], controller: "registry/films" do
      get "search", to: "registry/tmdb_film_search#index", on: :collection, as: :tmdb_search
    end
    resources :qualities, only: [ :index, :show ], controller: "registry/qualities"
    resources :quality_categories, path: "quality-categories", only: [ :index, :show ], controller: "registry/quality_categories"
  end

  # Defines the root path route ("/")
  root "landing#show"
end
