class LandingController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    session.delete(:entry_destination)
    if current_user.present?
      redirect_to current_user.default_entry_path
      return
    end

    films = Registry::CatalogueQueries::PreviewFilms.call(tmdb_ids: Identity::MarketingSamples::FILM_IDS).index_by(&:tmdb_id)
    examples = Identity::MarketingSamples::RATINGS.filter_map do |example|
      film = films[example.fetch(:tmdb_id)]
      example.merge(film:) if film.present?
    end
    render ::Views::Identity::Landing.new(examples:, films:)
  end
end
