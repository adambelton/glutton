namespace :community do
  desc "Seed a protected curation and two reusable preview members in development"
  task seed_protected_curation: :environment do
    abort "The protected curation seed only runs in development." unless Rails.env.development?

    require Rails.root.join("db/seeds/protected_curation")

    curation = Seeds::ProtectedCuration.call
    puts Rails.application.routes.url_helpers.community_post_path(curation)
  end
end
