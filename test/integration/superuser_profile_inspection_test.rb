require "test_helper"
require Rails.root.join("test/support/taste_profile_openai_stub")

class SuperuserProfileInspectionTest < ActionDispatch::IntegrationTest
  include TasteProfileOpenaiStub

  test "the selected user's saved claim points to the exact stored excerpt" do
    operator = create_user("operator", superuser: true)
    viewer = create_user("viewer")
    film = Registry::Film.create!(title: "A quiet film", release_date: Date.new(1986, 1, 1))
    candidate = Ratings::RatingFilm.create!(user: viewer, film:)
    quote = "<script>quiet</script>"
    rating = candidate.submit_rating!(value: "brilliant", notes: "Opening. 🎥 #{quote}. Ending.")
    revision = publish(viewer, quote:)
    candidate.revise_rating!(previous_rating_id: rating.id, value: "brilliant", notes: "Current unsynthesised note")

    sign_in(operator)
    get admin_user_path(viewer.id)
    assert_select "a[href=?]", glutton_profile_admin_user_path(viewer.id)
    get glutton_profile_admin_user_path(viewer.id)
    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    assert_select "main > a.admin-back[href=?] + h1", admin_user_path(viewer.id), text: "Glutton Profile for user #{viewer.id}"
    assert_select "main p", text: /Profile revision #{revision.id}/
    assert_select ".profile-narrative", "Enjoys quiet dread."
    assert_select "article h3", "Quiet scenes work for this viewer."
    assert_select "article p", "The cited scene builds dread."
    assert_select "article p", "A quiet film (1986) · Rating revision #{rating.id}" do
      assert_select ".film-year", "(1986)"
    end
    assert_select "blockquote", quote
    assert_select "blockquote script", count: 0
    refute_includes response.body, "Current unsynthesised note"
    assert_select "main form", count: 0

    get account_taste_profile_path
    assert_select "#saved-claims-heading", count: 0
    refute_includes response.body, "Quiet scenes work for this viewer."
  end

  test "the profile route requires a current superuser and handles empty and removed accounts" do
    viewer = create_user("viewer")
    path = glutton_profile_admin_user_path(viewer.id)
    get path
    assert_redirected_to new_session_path

    [ Identity::UserGuest.create!, viewer ].each do |user|
      sign_in(user)
      get path
      assert_response :forbidden
    end

    operator = create_user("operator", superuser: true)
    sign_in(operator)
    get path
    assert_response :success
    assert_select "p", "No saved claims and evidence for this profile."

    guest = Identity::UserGuest.create!
    removed_path = glutton_profile_admin_user_path(guest.id)
    guest.destroy_with_activity!
    get removed_path
    assert_response :not_found

    Identity::AccountAdministration::RevokeSuperuser.call(user_id: operator.id, actor_user_id: operator.id)
    get path
    assert_response :forbidden
  end

  private

  def create_user(name, superuser: false)
    Identity::UserRegistered.create!(email_address: "#{name}@example.test", password: "a long test password",
      password_confirmation: "a long test password", email_confirmed_at: Time.current, superuser:)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def publish(user, quote:)
    synthesize = lambda do |input:, **|
      note = input.fetch("note_changes").sole
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys quiet dread.", "conclusions" => [ { "anchor" => "Enjoys quiet dread.",
          "claim" => "Quiet scenes work for this viewer.", "explanation" => "The cited scene builds dread.",
          "citations" => [ { "rating_id" => note.fetch("after_rating_id"), "quote" => quote } ] } ] }
    end
    Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: user.id, client: taste_profile_openai_stub(synthesize), tracer_provider: nil)
  end
end
