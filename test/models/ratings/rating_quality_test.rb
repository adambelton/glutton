require "test_helper"

class Ratings::RatingQualityTest < ActiveSupport::TestCase
  test "submission and replacement wait for evaluation before scoring accepted qualities" do
    film = Registry::Film.create!(title: "Film with accepted qualities")
    category = quality_categories(:tone)
    [ "Atmosphere", "Dread" ].each do |name|
      quality = category.qualities.create!(name:)
      Registry::FilmQuality.create!(film:, quality:)
    end
    rating_film = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film:)
    values = Ratings::Rating::Values
    rating = rating_film.submit_rating!(value: values::BRILLIANT, expression_texts: [ "The atmosphere stood out." ])
    revision = rating_film.revise_rating!(previous_rating_id: rating.id, value: values::NOT_FOR_ME)

    assert_empty rating.rating_qualities
    assert_empty revision.rating_qualities
    assert_equal [ "The atmosphere stood out." ], rating.rating_expressions.pluck(:text)
  end

  test "submitting a rating for a film without accepted qualities records no scores" do
    film = Registry::Film.create!(title: "Film without accepted qualities")
    rating_film = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film:)

    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::PRETTY_GOOD)

    assert_empty rating.rating_qualities
  end
end
