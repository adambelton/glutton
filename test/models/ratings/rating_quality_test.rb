require "test_helper"

class Ratings::RatingQualityTest < ActiveSupport::TestCase
  test "submission and replacements record each accepted quality on its own rating version" do
    film = Registry::Film.create!(title: "Film with accepted qualities")
    category = quality_categories(:tone)
    quality_ids = [ "Atmosphere", "Dread" ].map do |name|
      quality = category.qualities.create!(name:)
      Registry::FilmQuality.create!(film:, quality:)
      quality.id
    end
    rating_film = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film:)
    values = Ratings::Rating::Values
    ratings = { values::BRILLIANT => 2, values::PRETTY_GOOD => 1, values::NOT_FOR_ME => -1, values::GARBAGE => -2 }

    rating = rating_film.submit_rating!(value: values::BRILLIANT, expression_texts: [ "The atmosphere stood out." ])
    previous_ratings = [ rating ]
    ratings.keys.drop(1).each do |value|
      rating = rating_film.revise_rating!(previous_rating_id: rating.id, value:)
      previous_ratings << rating
    end

    previous_ratings.each do |version|
      assert_equal quality_ids.map { |id| [ id, "unexpressed", ratings.fetch(version.value) ] },
        version.rating_qualities.order(:quality_id).pluck(:quality_id, :classification, :score)
    end
    assert_equal [ "The atmosphere stood out." ], previous_ratings.first.rating_expressions.pluck(:text)
  end

  test "submitting a rating for a film without accepted qualities records no scores" do
    film = Registry::Film.create!(title: "Film without accepted qualities")
    rating_film = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film:)

    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::PRETTY_GOOD)

    assert_empty rating.rating_qualities
  end
end
