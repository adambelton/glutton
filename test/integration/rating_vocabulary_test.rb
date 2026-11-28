require "test_helper"

class RatingVocabularyTest < ActionDispatch::IntegrationTest
  test "each vocabulary presents all four canonical values in their original order" do
    expected = {
      "international" => [ "Brilliant", "Pretty Good", "Not For Me", "Garbage" ],
      "england" => [ "Brilliant", "Quite Good", "Not My Cup of Tea", "Rubbish" ],
      "scotland" => [ "Class", "No Bad", "No Ma Thing", "Pish" ],
      "wales" => [ "Tidy", "Not Bad", "Not For Me", "Rubbish" ],
      "ireland" => [ "Class", "Grand", "Not My Thing", "Shite" ],
      "united_states" => [ "Awesome", "Pretty Good", "Not My Thing", "Trash" ],
      "canada" => [ "Wicked", "Pretty Decent", "Not For Me", "Garbage" ],
      "australia" => [ "Ripper", "Not Bad", "Not My Thing", "Shithouse" ],
      "new_zealand" => [ "Choice", "Sweet As", "Nah", "Rubbish" ],
      "south_africa" => [ "Lekker", "Not Too Bad", "Not My Thing", "Kak" ],
      "scouse" => [ "Boss", "Sound", "Not Arsed", "Shite" ]
    }
    assert_equal expected, Identity::RatingVocabularies::ALL.index_with { |key| Shared::RatingVocabulary.new(key).labels.values }
    [ nil, "unknown" ].each { |key| assert_equal expected.fetch("international"), Shared::RatingVocabulary.new(key).labels.values }
  end

  test "the saved vocabulary reaches Watched filters, rating tooltips and notification choices" do
    user = registered_user
    sign_in(user)
    film = Registry::Film.create!(title: "Uncanny Manor")
    rating = Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant")
    Library::CollectionManagement::MarkWatched.call(user_id: user.id, film_id: film.id)

    get account_settings_path
    assert_select "#account-rating-vocabulary", "International"
    patch account_rating_vocabulary_path, params: { vocabulary: "scouse", user_id: Identity::UserGuest.create!.id }
    assert_redirected_to account_settings_path
    assert_equal "scouse", user.reload.rating_vocabulary
    follow_redirect!
    assert_select "#account-rating-vocabulary", "Scouse"

    get library_path(view: "watched", ratings: [ "brilliant" ])
    assert_select '.library-rating-filters a[data-selected="true"]', text: "Boss", count: 1
    assert_select "[data-tooltip=?]", I18n.t("library.browser.edit_rating", value: "Boss")
    assert_equal "brilliant", rating.reload.value

    get account_community_path
    assert_select 'label:has(input[name="rating_values[]"][value="brilliant"])', text: "Boss"
    assert_select 'label:has(input[name="rating_values[]"][value="unrated"])', text: I18n.t("community.notifications.unrated")

    patch account_rating_vocabulary_path, params: { vocabulary: "invalid" }
    assert_response :unprocessable_entity
    assert_equal "scouse", user.reload.rating_vocabulary

    patch account_rating_vocabulary_path, params: { vocabulary: "international" }
    assert_redirected_to account_settings_path
    assert_nil user.reload.rating_vocabulary
  end

  test "signed-out viewers and guests cannot change a vocabulary" do
    patch account_rating_vocabulary_path, params: { vocabulary: "england" }
    assert_response :unauthorized

    guest = Identity::UserGuest.create!
    sign_in(guest)
    patch account_rating_vocabulary_path, params: { vocabulary: "england" }
    assert_response :forbidden
    assert_nil guest.reload.rating_vocabulary
  end

  private

  def registered_user
    password = "a long test password"
    Identity::UserRegistered.create!(email_address: "vocabulary@example.test", password:, password_confirmation: password, email_confirmed_at: Time.current)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end
end
