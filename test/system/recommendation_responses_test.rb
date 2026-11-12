require "application_system_test_case"
require_relative "../support/assessed_recommendation_films"

class RecommendationResponsesTest < ApplicationSystemTestCase
  include AssessedRecommendationFilms

  test "accepting and rejecting advance the queue and save distinct responses" do
    first = Registry::Film.create!(title: "A recommendation to accept")
    second = Registry::Film.create!(title: "A recommendation to reject")
    third = Registry::Film.create!(title: "Next recommendation")
    visit recommendation_path
    click_button I18n.t("identity.entry.try_it_out")
    assert_current_path recommendation_path

    user = Identity::Session.last.user
    unlock_recommendations_for(user:)
    visit recommendation_path
    assert_selector "h2", text: first.title

    click_button I18n.t("recommendations.accept")
    assert_current_path recommendation_path
    assert_selector '[role="status"]', text: I18n.t("recommendations.responses.accepted")
    assert_selector "h2", text: second.title
    assert_equal "accepted", Recommendations::RecommendationFilm.find_by!(user:, film: first).response

    click_button I18n.t("recommendations.reject")
    assert_current_path recommendation_path
    assert_selector '[role="status"]', text: I18n.t("recommendations.responses.rejected")
    assert_selector "h2", text: third.title
    assert_equal "rejected", Recommendations::RecommendationFilm.find_by!(user:, film: second).response

    accepted = DomainEvents::DomainEvent.where(name: Recommendations::Events::RECOMMENDATION_ACCEPTED).sole
    assert_equal first.id, accepted.payload.fetch("film_id")
    assert_not Library::LibraryFilm.exists?(user:, film: first)
  end
end
