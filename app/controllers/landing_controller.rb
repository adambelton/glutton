class LandingController < ApplicationController
  allow_unauthenticated_access only: :show

  EXAMPLES = [
    { key: "alien", tmdb_id: 348, rating: Ratings::Rating::Values::BRILLIANT },
    { key: "the_thing", tmdb_id: 1091, rating: Ratings::Rating::Values::I_ENJOYED_THAT },
    { key: "get_out", tmdb_id: 419430, rating: Ratings::Rating::Values::NOT_FOR_ME }
  ].freeze

  def show
    session.delete(:entry_destination)
    if current_user.present?
      redirect_to current_user.default_entry_path
      return
    end

    films = Registry::PreviewFilms.call(tmdb_ids: EXAMPLES.map { |example| example.fetch(:tmdb_id) }).index_by(&:tmdb_id)
    examples = EXAMPLES.filter_map do |example|
      film = films[example.fetch(:tmdb_id)]
      example.merge(film:) if film.present?
    end
    render ::Views::Identity::Landing.new(examples:)
  end
end
