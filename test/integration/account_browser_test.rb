require "test_helper"

require Rails.root.join("test/support/taste_profile_openai_stub")

class AccountBrowserTest < ActionDispatch::IntegrationTest
  include TasteProfileOpenaiStub
  include ActiveJob::TestHelper

  test "only registered viewers can read the account and only superusers can queue a refresh" do
    get account_taste_profile_path
    assert_redirected_to new_session_path

    sign_in(Identity::UserGuest.create!)
    get account_taste_profile_path
    assert_response :forbidden

    sign_in(registered_user)
    get new_rating_path
    assert_select "header a[href=?]", account_settings_path, count: 1
    assert_select "header select option[value=?]", account_settings_path, text: I18n.t("account.title")
    get account_path
    assert_redirected_to account_settings_path
    get account_taste_profile_path
    assert_response :success
    assert_select "#pending-evidence-heading", count: 0
    assert_select "form[action=?]", refresh_taste_profile_account_path, count: 0
    assert_select "p", I18n.t("account.quality_rankings.top_empty")
    assert_select "p", I18n.t("account.quality_rankings.bottom_empty")
    assert_no_enqueued_jobs(only: Ratings::RefreshTasteProfilesJob) do
      post refresh_taste_profile_account_path
      assert_response :forbidden
    end
  end

  test "the account shows historical annotations and only the signed-in user's pending evidence" do
    user = registered_user(superuser: true)
    rating = submit(user, "Old <script>expression</script>")
    revision = publish(user)
    rating.rating_film.revise_rating!(previous_rating_id: rating.id, value: "brilliant", notes: "New expression")
    other = registered_user(superuser: true)
    submit(other, "Private foreign expression")
    publish(other)
    sign_in(user)

    get account_taste_profile_path, params: { user_id: other.id }
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "header nav a[href=?] + a[href=?]", account_settings_path, registry_root_path
    assert_select "header form[action=?]", session_path, count: 0
    assert_select ".account-tabs a[aria-current=page]", I18n.t("account.profile")
    assert_select ".profile-narrative a[href='#profile-evidence-1']", text: "[1]"
    assert_select "#profile-evidence-1 strong", "Enjoys quiet dread."
    assert_select "#profile-evidence-1 blockquote", "Old <script>expression</script>"
    assert_select "#profile-evidence-1 p", I18n.t("account.earlier_rating_evidence")
    assert_select "#profile-evidence-1 script", count: 0
    assert_select "#profile-evidence-1 a[href=?]", edit_rating_path(film_id: rating.rating_film.film_id)
    assert_select "section[aria-labelledby=pending-evidence-heading] li", text: "New expression"
    assert_select "section[aria-labelledby=pending-evidence-heading] li", text: "Old <script>expression</script>"
    refute_includes response.body, "Private foreign expression"
    assert_equal revision.id, Ratings::TasteProfile.find_by!(user:).current_revision.id

    token = Nokogiri::HTML(response.body).at_css('form[action="' + refresh_taste_profile_account_path + '"] input[name="authenticity_token"]')&.[]("value")
    assert_enqueued_with(job: Ratings::RefreshTasteProfilesJob, args: [ user.id ]) do
      post refresh_taste_profile_account_path, params: { authenticity_token: token, user_id: other.id }
    end
    assert_redirected_to account_taste_profile_path
  end

  test "citations resolve to identical current notes and label earlier notes until refresh" do
    user = registered_user(superuser: true)
    rating = submit(user, "The silence built dread.")
    assessed = publish(user)
    candidate = rating.rating_film
    identical = candidate.revise_rating!(previous_rating_id: rating.id, value: "pretty_good", notes: rating.notes)
    sign_in(user)

    get account_taste_profile_path
    assert_select "#profile-evidence-1 blockquote", rating.notes
    assert_select "#profile-evidence-1 p", text: I18n.t("account.earlier_rating_evidence"), count: 0
    evidence = Ratings::TasteProfiling::ViewTasteProfile.call(user_id: user.id).fetch(:annotations).sole.fetch(:evidence).sole
    assert_equal identical.id, evidence.fetch("rating_id")
    assert_equal [ rating.id ], assessed.reload.annotations.sole.fetch("citations").pluck("rating_id")
    assert_equal [ rating.id ], assessed.taste_profile_revision_eval.output.fetch("evidence").pluck("rating_id")

    changed = candidate.revise_rating!(previous_rating_id: identical.id, value: "pretty_good", notes: "The quiet ending felt eerie.")
    get account_taste_profile_path
    assert_select "#profile-evidence-1 blockquote", rating.notes
    assert_select "#profile-evidence-1 p", I18n.t("account.earlier_rating_evidence")

    publish(user)
    get account_taste_profile_path
    assert_select "#profile-evidence-1 blockquote", changed.notes
    assert_select "#profile-evidence-1 p", text: I18n.t("account.earlier_rating_evidence"), count: 0
  end

  test "a superuser without a profile sees the empty state and pending expressions" do
    user = registered_user(superuser: true)
    submit(user, "My first expression")
    sign_in(user)

    get account_taste_profile_path
    assert_response :success
    assert_select "p", I18n.t("account.empty")
    assert_select "li", "My first expression"
  end

  test "quality rankings limit each list and exclude canceled and superseded scores without a written profile" do
    user = registered_user
    category = quality_categories(:tone)
    positives = 11.times.map do |i|
      category.qualities.create!(name: "Positive #{i}", match_rule: "A definition for quality #{i}.", not_sufficient: "An exclusion.")
    end
    negatives = 11.times.map { |i| category.qualities.create!(name: "Negative #{i}") }
    canceled = category.qualities.create!(name: "Canceled")
    stale = category.qualities.create!(name: "Superseded")
    assess(user, "pretty_good", *positives, canceled)
    assess(user, "not_for_me", *negatives, canceled)
    assess(user, "brilliant", positives.last)
    assess(user, "garbage", negatives.last)
    rating = assess(user, "brilliant", stale)
    rating.rating_film.revise_rating!(previous_rating_id: rating.id, value: "garbage")
    assess(registered_user, "brilliant", stale)
    sign_in(user)

    get account_taste_profile_path
    assert_response :success
    assert_select "p", I18n.t("account.empty")
    assert_select ".profile-quality-rankings ol", count: 0
    assert_select 'section[aria-labelledby="top-qualities-heading"] .profile-quality-score', text: "+3", count: 1
    assert_select 'section[aria-labelledby="bottom-qualities-heading"] .profile-quality-score', text: "-3", count: 1
    assert_select ".profile-quality-item p", text: positives.last.match_rule, count: 1
    assert_select 'section[aria-labelledby="top-qualities-heading"] .profile-quality-name' do |items|
      assert_equal [ positives.last, *positives.first(9) ].map(&:name), items.map(&:text)
    end
    assert_select 'section[aria-labelledby="bottom-qualities-heading"] .profile-quality-name' do |items|
      assert_equal [ negatives.last, *negatives.first(9) ].map(&:name), items.map(&:text)
    end
  end

  private

  def assess(user, value, *qualities)
    film = Registry::Film.create!(title: "Rated film")
    qualities.each { |quality| Registry::FilmQuality.create!(film:, quality:) }
    rating = Ratings::RatingFilm.create!(user:, film:).submit_rating!(value:)
    evaluation = Ratings::RatingQualityEval.create!(rating:, input: [], output: {
      notes: {}, calls: [],
      qualities: qualities.to_h { |quality| [ quality.id.to_s, { name: quality.name, match_rule: nil, not_sufficient: nil } ] },
      decisions: qualities.map { |quality| { quality_id: quality.id, applicable: false, supporting_rating_ids: [], result_ids: [] } }
    })
    rating.apply_quality_evaluation!(evaluation:)
    rating
  end

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
    Ratings::RatingFilm.create!(user:, film:).submit_rating!(value: "brilliant", notes: expression)
  end

  def publish(user)
    synthesizer = lambda do |input:, **|
      expressions = input.fetch("note_changes").select { |change| change.fetch("after_rating_id") }
      note = expressions.sole
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys quiet dread.", "conclusions" => [ { "anchor" => "Enjoys quiet dread.", "claim" => "Enjoys quiet dread.", "explanation" => "The source describes dread.", "citations" => [ { "rating_id" => note.fetch("after_rating_id"), "quote" => note.fetch("after") } ] } ] }
    end
    Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)
  end
end
