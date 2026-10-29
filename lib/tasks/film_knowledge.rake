namespace :film_knowledge do
  desc "Load three development sample film identities without changing existing metadata"
  task load_sample: :environment do
    films = FilmKnowledge::LoadDevelopmentSample.call
    puts "sample_films=#{films.size}"
  end
end
