require "test_helper"

class AccountBrowserTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "only superusers can read the account or queue a refresh" do
    get account_path
    assert_redirected_to new_session_path

    sign_in(registered_user)
    get new_rating_path
    assert_select "header a[href=?]", account_path, count: 0
    get account_path
    assert_response :forbidden
    assert_no_enqueued_jobs(only: Ratings::RefreshExpressionProfilesJob) do
      post refresh_expression_profile_account_path
      assert_response :forbidden
    end
  end

  test "the account shows historical annotations and only the signed-in user's pending evidence" do
    user = registered_user(superuser: true)
    rating = submit(user, "Old <script>expression</script>")
    revision = publish(user)
    rating.rating_film.revise_rating!(previous_rating_id: rating.id, value: "brilliant", expression_texts: [ "New expression" ])
    other = registered_user(superuser: true)
    submit(other, "Private foreign expression")
    publish(other)
    sign_in(user)

    get account_path, params: { user_id: other.id }
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "header a[href=?]", account_path, text: I18n.t("account.title")
    assert_select ".account-tabs a[aria-current=page]", I18n.t("account.profile")
    assert_select ".profile-narrative a[href='#profile-evidence-1']", text: "[1]"
    assert_select "#profile-evidence-1 strong", "Enjoys quiet dread."
    assert_select "#profile-evidence-1 blockquote", "Old <script>expression</script>"
    assert_select "#profile-evidence-1 script", count: 0
    assert_select "#profile-evidence-1 a[href=?]", edit_rating_path(film_id: rating.rating_film.film_id)
    assert_select "section[aria-labelledby=pending-evidence-heading] li", text: "New expression"
    assert_select "section[aria-labelledby=pending-evidence-heading] li", text: "Old <script>expression</script>"
    refute_includes response.body, "Private foreign expression"
    assert_equal revision.id, Ratings::ExpressionProfile.find_by!(user:).current_revision.id

    token = Nokogiri::HTML(response.body).at_css('form[action="' + refresh_expression_profile_account_path + '"] input[name="authenticity_token"]')&.[]("value")
    assert_enqueued_with(job: Ratings::RefreshExpressionProfilesJob, args: [ user.id ]) do
      post refresh_expression_profile_account_path, params: { authenticity_token: token, user_id: other.id }
    end
    assert_redirected_to account_path
  end

  test "a superuser without a profile sees the empty state and pending expressions" do
    user = registered_user(superuser: true)
    submit(user, "My first expression")
    sign_in(user)

    get account_path
    assert_response :success
    assert_select "p", I18n.t("account.empty")
    assert_select "li", "My first expression"
  end

  private

  def registered_user(superuser: false)
    Identity::UserRegistered.create!(email_address: "account-#{Identity::User.count}@example.test", password: "a long test password",
      password_confirmation: "a long test password", email_confirmed_at: Time.current, superuser:)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def submit(user, expression)
    film = Registry::Film.create!(title: "Quiet dread")
    Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant", expression_texts: [ expression ])
  end

  def publish(user)
    synthesizer = lambda do |expressions:, **|
      id = expressions.sole.fetch("expressions").sole.fetch("expression_id")
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys quiet dread.", "conclusions" => [ { "anchor" => "Enjoys quiet dread.", "claim" => "Enjoys quiet dread.", "explanation" => "The source describes dread.", "expression_ids" => [ id ] } ] }
    end
    Ratings::RefreshExpressionProfile.call(user_id: user.id, synthesizer:, tracer_provider: nil)
  end
end
