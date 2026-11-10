class LandingController < ApplicationController
  allow_unauthenticated_access only: :show

  EXAMPLES = [
    { key: "alien", tmdb_id: 348, rating: Ratings::Rating::Values::BRILLIANT },
    { key: "the_thing", tmdb_id: 1091, rating: Ratings::Rating::Values::PRETTY_GOOD },
    { key: "halloween", tmdb_id: 948, rating: Ratings::Rating::Values::BRILLIANT },
    { key: "the_exorcist", tmdb_id: 9552, rating: Ratings::Rating::Values::NOT_FOR_ME },
    { key: "american_werewolf", tmdb_id: 814, rating: Ratings::Rating::Values::PRETTY_GOOD }
  ].freeze

  def show
    session.delete(:entry_destination)
    if current_user.present?
      redirect_to current_user.default_entry_path
      return
    end

    films = Registry::CatalogueQueries::PreviewFilms.call(tmdb_ids: EXAMPLES.map { |example| example.fetch(:tmdb_id) }).index_by(&:tmdb_id)
    examples = EXAMPLES.filter_map do |example|
      film = films[example.fetch(:tmdb_id)]
      example.merge(film:) if film.present?
    end
    render ::Views::Identity::Landing.new(examples:)
  end
end
