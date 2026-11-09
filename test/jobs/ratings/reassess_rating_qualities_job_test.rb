require "test_helper"

class Ratings::ReassessRatingQualitiesJobTest < ActiveSupport::TestCase
  Job = Ratings::ReassessRatingQualitiesJob
  Request = Ratings::RatingQualityReassessmentRequest

  setup do
    @adapter = Job.queue_adapter
    Job.queue_adapter = :good_job
    @provider_constructor = TypeSafeClient.method(:new)
    @user = Identity::UserGuest.create!
    @quality = quality_categories(:tone).qualities.create!(name: "Dread")
    @source = rating_film("Expression source")
    @target = rating_film("Film to reassess", quality: @quality).submit_rating!(value: "brilliant")
    @other_target = rating_film("Another film", quality: @quality).submit_rating!(value: "brilliant")
  end

  teardown do
    Job.queue_adapter = @adapter
    TypeSafeClient.define_singleton_method(:new, @provider_constructor)
  end

  test "only the newest pending revision reassesses each current rating after a backlog" do
    source = @source.submit_rating!(value: "brilliant", expression_texts: [ "Original expression" ])
    first = publish("Original profile")
    @source.revise_rating!(previous_rating_id: source.id, value: "brilliant", expression_texts: [ "New expression" ])
    newest = publish("New profile")
    assert_equal newest.id, Request.sole.expression_profile_revision_id
    assert_equal 2, jobs.count

    Job.enqueue!(user_id: @user.id, profile_revision_id: newest.id)
    requests = []
    stub_provider do |state:, questions:, **|
      requests << state.fetch(:expression_profile)
      assert perform_revision(newest).retried? if requests.one?
      response(questions)
    end

    assert_nil perform_revision(first).unhandled_error
    assert_empty requests
    assert_nil perform_revision(newest).unhandled_error
    travel 1.minute do
      assert_nil perform_revision(newest).unhandled_error
    end
    assert_equal [ newest.profile, newest.profile ], requests
    assert_empty Request.all
    [ @target, @other_target ].each do |rating|
      evaluation = rating.rating_quality_evals.sole
      assert_equal newest.id, evaluation.profile_revision_id
      assert_equal [ 4 ], evaluation.rating_qualities.pluck(:score)
    end
  end

  test "an older running job cannot acknowledge the newer pending revision" do
    source = @source.submit_rating!(value: "brilliant", expression_texts: [ "Original expression" ])
    first = publish("Original profile")
    newest = nil
    stub_provider do |state:, questions:, **|
      if state.fetch(:expression_profile) == first.profile
        assert_nil newest
        @source.revise_rating!(previous_rating_id: source.id, value: "brilliant", expression_texts: [ "New expression" ])
        newest = publish("New profile")
      end
      response(questions)
    end

    assert_nil perform_revision(first).unhandled_error
    assert_equal newest.id, Request.sole.expression_profile_revision_id
    assert_equal 1, [ @target, @other_target ].sum { |rating| rating.rating_quality_evals.count }
    assert_nil perform_revision(newest).unhandled_error
    assert_empty Request.all
    [ @target, @other_target ].each do |rating|
      assert_equal newest.id, rating.rating_quality_evals.order(:id).last.profile_revision_id
    end
  end

  test "publication rollback leaves no pending request or durable job, and unchanged evidence adds no work" do
    @source.submit_rating!(value: "brilliant", expression_texts: [ "Original expression" ])
    Ratings::ExpressionProfile.transaction(requires_new: true) do
      publish("Original profile")
      assert_equal 1, Request.count
      assert_equal 1, jobs.count
      raise ActiveRecord::Rollback
    end
    assert_empty Request.all
    assert_empty jobs
    assert_empty Ratings::ExpressionProfileRevision.all

    revision = publish("Original profile")
    assert_equal revision, publish("Unused profile")
    assert_equal 1, jobs.count
  end

  test "failure retains pending work and recovery skips ratings that already applied" do
    @source.submit_rating!(value: "brilliant", expression_texts: [ "Original expression" ])
    revision = publish("Original profile")
    calls = 0
    stub_provider do |questions:, **|
      calls += 1
      raise TypeSafeClient::Error.new(reason: :timeout, request_sent: true) if calls == 2

      response(questions)
    end

    assert_instance_of Ratings::QualityAssessmentFailed, perform_revision(revision).unhandled_error
    assert_equal revision.id, Request.sole.expression_profile_revision_id
    assert_equal 1, [ @target, @other_target ].sum { |rating| rating.rating_quality_evals.count }

    Job.enqueue!(user_id: @user.id, profile_revision_id: revision.id)
    assert_nil perform_revision(revision).unhandled_error
    assert_equal 3, calls
    assert_empty Request.all
  end

  private

  def rating_film(title, quality: nil)
    film = Registry::Film.create!(title:)
    Registry::FilmQuality.create!(film:, quality:) if quality.present?
    Ratings::RatingFilm.create!(user: @user, film:)
  end

  def publish(profile)
    synthesizer = lambda do |expressions:, **|
      ids = expressions.flat_map { |film| film.fetch("expressions").pluck("expression_id") }
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "paragraphs" => [ { "text" => profile, "explanation" => "Source expression", "expression_ids" => ids } ] }
    end
    Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer:, tracer_provider: nil)
  end

  def jobs
    GoodJob::Job.where(job_class: Job.name)
  end

  def perform_revision(revision)
    jobs.where("serialized_params->'arguments' = ?::jsonb", [ @user.id, revision.id ].to_json)
      .perform_with_lock(lock_id: SecureRandom.uuid, lock_strategy: :skiplocked)
  end

  def stub_provider(&answer)
    client = Object.new
    client.define_singleton_method(:answer) { |**request| answer.call(**request) }
    client.define_singleton_method(:configuration) { { "model" => "jev-1.14.0" } }
    TypeSafeClient.define_singleton_method(:new) { |**| client }
  end

  def response(questions)
    { "model" => "jev-1.14.0", "usage" => { "input_tokens" => 10, "output_tokens" => 2 },
      "answers" => questions.keys.index_with({ "type" => "noul", "noul" => 0.90 }) }
  end
end
