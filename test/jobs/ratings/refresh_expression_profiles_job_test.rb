require "test_helper"

class Ratings::RefreshExpressionProfilesJobTest < ActiveSupport::TestCase
  Job = Ratings::RefreshExpressionProfilesJob

  setup do
    @adapter = Job.queue_adapter
    Job.queue_adapter = :good_job
    @constructor = Ratings::ExpressionProfileSynthesizer.method(:new)
  end

  teardown do
    Job.queue_adapter = @adapter
    Ratings::ExpressionProfileSynthesizer.define_singleton_method(:new, @constructor)
  end

  test "quarter-hour cron runs one batch at a time and the next tick recovers pending work" do
    cron = GoodJob::CronEntry.find(:ratings_expression_profile_refresh)
    tick = Time.utc(2026, 11, 9, 10)
    travel_to tick
    assert_equal [ tick + 15.minutes ], cron.within((tick + 1.second)..(tick + 15.minutes + 1.second))
    refute cron.enabled_by_default?

    user = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Quiet dread")
    rating_film = Ratings::RatingFilm.create!(user:, film:)
    rating_film.submit_rating!(value: "brilliant", expression_texts: [ "I liked the quiet dread." ])
    calls = 0
    synthesizer = lambda do |expressions:, **|
      calls += 1
      raise Ratings::ExpressionProfileRefreshFailed.new(reason: :provider_failure) if calls == 1

      ids = expressions.sole.fetch("expressions").pluck("expression_id")
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys quiet dread.", "conclusions" => [ { "anchor" => "Enjoys quiet dread.", "claim" => "Enjoys quiet dread.", "explanation" => "The viewer praised quiet dread.", "expression_ids" => ids } ] }
    end
    Ratings::ExpressionProfileSynthesizer.define_singleton_method(:new) { synthesizer }

    cron.enqueue(tick)
    travel 15.minutes
    cron.enqueue(tick + 15.minutes)
    assert_equal "ratings_assessment", cron.jobs.sole.queue_name
    assert_nil perform_next(cron).unhandled_error
    assert Ratings::ExpressionProfileRefreshRequest.exists?(user:)

    travel 15.minutes
    cron.enqueue(tick + 30.minutes)
    assert_nil perform_next(cron).unhandled_error
    assert_equal 2, calls
    refute Ratings::ExpressionProfileRefreshRequest.exists?(user:)
    revision = Ratings::ExpressionProfile.find_by!(user:).current_revision
    assert_equal "Enjoys quiet dread.", revision.profile
    assert_equal revision.id, Ratings::RatingQualityReassessmentRequest.find_by!(user:).expression_profile_revision_id
  end

  test "manual refresh is scoped to one superuser and coalesces duplicate requests" do
    user = Identity::UserRegistered.create!(email_address: "refresh@example.test", password: "a long test password",
      password_confirmation: "a long test password", email_confirmed_at: Time.current, superuser: true)
    other = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Quiet dread")
    [ user, other ].each do |viewer|
      Ratings::RatingFilm.create!(user: viewer, film:).submit_rating!(value: "brilliant", expression_texts: [ "Expression #{viewer.id}" ])
    end
    cron = GoodJob::CronEntry.find(:ratings_expression_profile_refresh)
    requests = []
    synthesizer = lambda do |expressions:, **|
      expression = expressions.sole.fetch("expressions").sole
      requests << expression.fetch("text")
      cron.enqueue(Time.current)
      assert perform_next(cron).retried?

      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys dread.", "conclusions" => [ { "anchor" => "Enjoys dread.", "claim" => "Enjoys dread.", "explanation" => "Source expression.",
          "expression_ids" => [ expression.fetch("expression_id") ] } ] }
    end
    Ratings::ExpressionProfileSynthesizer.define_singleton_method(:new) { synthesizer }

    assert Job.perform_later(user.id)
    assert_equal false, Job.perform_later(user.id)
    assert Job.perform_later(other.id)
    jobs = GoodJob::Job.where(job_class: Job.name, cron_key: nil)
    2.times do
      assert_nil jobs.perform_with_lock(lock_id: SecureRandom.uuid, lock_strategy: :skiplocked).unhandled_error
    end

    assert_equal [ "Expression #{user.id}" ], requests
    assert Ratings::ExpressionProfile.exists?(user:)
    refute Ratings::ExpressionProfile.exists?(user: other)
    assert Ratings::ExpressionProfileRefreshRequest.exists?(user: other)
  end

  private

  def perform_next(cron)
    cron.jobs.perform_with_lock(lock_id: SecureRandom.uuid, lock_strategy: :skiplocked)
  end
end
