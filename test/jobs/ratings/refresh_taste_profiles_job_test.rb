require "test_helper"

require Rails.root.join("test/support/taste_profile_openai_stub")

class Ratings::RefreshTasteProfilesJobTest < ActiveSupport::TestCase
  include TasteProfileOpenaiStub
  Job = Ratings::RefreshTasteProfilesJob

  setup do
    @adapter = Job.queue_adapter
    Job.queue_adapter = :good_job
    @openai_client = Rails.application.config.x.openai_client
  end

  teardown do
    Job.queue_adapter = @adapter
    Rails.application.config.x.openai_client = @openai_client
  end

  test "quarter-hour cron runs one batch at a time and the next tick recovers pending work" do
    cron = GoodJob::CronEntry.find(:ratings_taste_profile_refresh)
    tick = Time.utc(2026, 11, 9, 10)
    travel_to tick
    assert_equal [ tick + 15.minutes ], cron.within((tick + 1.second)..(tick + 15.minutes + 1.second))
    refute cron.enabled_by_default?

    user = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Quiet dread")
    rating_film = Ratings::RatingFilm.create!(user:, film:)
    rating_film.submit_rating!(value: "brilliant", notes: "I liked the quiet dread.")
    calls = 0
    synthesizer = lambda do |input:, **|
      notes = input.fetch("note_changes").select { |change| change.fetch("after_rating_id") }
      calls += 1
      raise Ratings::Errors::TasteProfileRefreshFailed.new(reason: :provider_failure) if calls == 1

      note = notes.sole
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys quiet dread.", "conclusions" => [ { "anchor" => "Enjoys quiet dread.", "claim" => "Enjoys quiet dread.", "explanation" => "The viewer praised quiet dread.", "citations" => [ { "rating_id" => note.fetch("after_rating_id"), "quote" => note.fetch("after") } ] } ] }
    end
    Rails.application.config.x.openai_client = taste_profile_openai_stub(synthesizer)

    cron.enqueue(tick)
    travel 15.minutes
    cron.enqueue(tick + 15.minutes)
    assert_equal "ratings_assessment", cron.jobs.sole.queue_name
    assert_nil perform_next(cron).unhandled_error
    assert Ratings::TasteProfileRefreshRequest.exists?(user:)

    travel 15.minutes
    cron.enqueue(tick + 30.minutes)
    assert_nil perform_next(cron).unhandled_error
    assert_equal 2, calls
    refute Ratings::TasteProfileRefreshRequest.exists?(user:)
    revision = Ratings::TasteProfile.find_by!(user:).current_revision
    assert_equal "Enjoys quiet dread.", revision.profile
    assert_equal revision.id, Ratings::RatingQualityReassessmentRequest.find_by!(user:).taste_profile_revision_id
  end

  test "manual refresh is scoped to one superuser and coalesces duplicate requests" do
    user = Identity::UserRegistered.create!(email_address: "refresh@example.test", password: "a long test password",
      password_confirmation: "a long test password", email_confirmed_at: Time.current, superuser: true)
    other = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Quiet dread")
    [ user, other ].each do |viewer|
      Ratings::RatingFilm.create!(user: viewer, film:).submit_rating!(value: "brilliant", notes: "Reflection #{viewer.id}")
    end
    cron = GoodJob::CronEntry.find(:ratings_taste_profile_refresh)
    requests = []
    synthesizer = lambda do |input:, **|
      notes = input.fetch("note_changes").select { |change| change.fetch("after_rating_id") }
      notes = notes.sole
      requests << notes.fetch("after")
      cron.enqueue(Time.current)
      assert perform_next(cron).retried?

      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => "Enjoys dread.", "conclusions" => [ { "anchor" => "Enjoys dread.", "claim" => "Enjoys dread.", "explanation" => "Source notes.",
          "citations" => [ { "rating_id" => notes.fetch("after_rating_id"), "quote" => notes.fetch("after") } ] } ] }
    end
    Rails.application.config.x.openai_client = taste_profile_openai_stub(synthesizer)

    assert Job.perform_later(user.id)
    assert_equal false, Job.perform_later(user.id)
    assert Job.perform_later(other.id)
    jobs = GoodJob::Job.where(job_class: Job.name, cron_key: nil)
    2.times do
      assert_nil jobs.perform_with_lock(lock_id: SecureRandom.uuid, lock_strategy: :skiplocked).unhandled_error
    end

    assert_equal [ "Reflection #{user.id}" ], requests
    assert Ratings::TasteProfile.exists?(user:)
    refute Ratings::TasteProfile.exists?(user: other)
    assert Ratings::TasteProfileRefreshRequest.exists?(user: other)
  end

  private

  def perform_next(cron)
    cron.jobs.perform_with_lock(lock_id: SecureRandom.uuid, lock_strategy: :skiplocked)
  end
end
