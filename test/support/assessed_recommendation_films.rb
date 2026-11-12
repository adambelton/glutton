module AssessedRecommendationFilms
  def unlock_recommendations_for(user:)
    quality = quality_categories(:tone).qualities.create!(name: "Slow pace")
    5.times do |index|
      film = Registry::Film.create!(title: "Rated film #{index}")
      assess_recommendation_film(user:, film:, quality:)
    end
  end

  def assess_recommendation_film(user:, film:, quality:)
    Registry::FilmQuality.create!(film:, quality:)
    rating_film = Ratings::RatingFilm.create!(user:, film:)
    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    evaluation = Ratings::RatingQualityEval.create!(rating:, input: [], output: {
      notes: {}, qualities: { quality.id.to_s => { name: quality.name, match_rule: nil, not_sufficient: nil } },
      calls: [], decisions: [ { quality_id: quality.id, applicable: false, supporting_rating_ids: [], result_ids: [] } ]
    })
    rating.apply_quality_evaluation!(evaluation:)
    Recommendations::RecommendationFilm.new(user:, film:).suppress!
  end
end
