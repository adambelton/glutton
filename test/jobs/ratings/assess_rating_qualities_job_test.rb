require "test_helper"

class Ratings::AssessRatingQualitiesJobTest < ActiveSupport::TestCase
  Job = Ratings::AssessRatingQualitiesJob

  setup do
    @adapter = Job.queue_adapter
    Job.queue_adapter = :good_job
    @original_client_constructor = TypeSafeClient.method(:new)
    stub_provider { flunk "Unexpected TypeSafe request" }
    @user = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Assessed film")
    @rating_film = Ratings::RatingFilm.create!(user: @user, film:)
    @quality = quality_categories(:tone).qualities.create!(name: "Dread")
    Registry::FilmQuality.create!(film:, quality: @quality)
  end

  teardown do
    Job.queue_adapter = @adapter
    TypeSafeClient.define_singleton_method(:new, @original_client_constructor)
  end

  test "submission and revision enqueue only the exact saved rating IDs" do
    first = submit
    replacement = revise(first)

    assert_equal [ [ first.id ], [ replacement.id ] ],
      jobs.order(:created_at).map { |job| job.serialized_params.fetch("arguments") }
  end

  test "invalid saves and caller rollback leave no durable job" do
    assert_no_difference [ -> { jobs.count }, -> { Ratings::Rating.count } ] do
      assert_raises(ActiveRecord::RecordInvalid) { submit(value: "invalid") }

      Ratings::Rating.transaction(requires_new: true) do
        first = submit
        revise(first)
        assert_equal 2, jobs.count
        raise ActiveRecord::Rollback
      end
    end
  end

  test "an enqueue error rolls back the rating, expressions and Library event" do
    failing_adapter = ActiveJob::QueueAdapters::TestAdapter.new
    failing_adapter.define_singleton_method(:enqueue) { |_| raise ActiveJob::EnqueueError, "Queue write failed" }
    Job.queue_adapter = failing_adapter

    assert_no_difference [ "Ratings::Rating.count", "Ratings::RatingExpression.count", "DomainEvents::DomainEvent.count" ] do
      assert_raises(ActiveJob::EnqueueError) { submit(expressions: [ "Dread builds slowly." ]) }
    end
  end

  test "overlapping delivery waits and then reuses the completed evaluation" do
    rating = submit(expressions: [ "Dread builds slowly." ])
    duplicate = Job.enqueue!(rating.id)
    requests = 0
    stub_provider do |questions:, **|
      requests += 1
      assert_equal 1, requests
      assert perform_next.retried?
      assert_nil jobs.find_by!(active_job_id: duplicate.job_id).finished_at
      { "model" => "jev-1.14.0", "usage" => { "input_tokens" => 10, "output_tokens" => 2 },
        "answers" => questions.keys.index_with({ "type" => "noul", "noul" => 0.9 }) }
    end

    assert_nil perform_next.unhandled_error
    travel 1.minute do
      assert_nil perform_next.unhandled_error
      assert_empty jobs.unfinished
    end
    assert_equal 1, requests
    evaluation = rating.rating_quality_evals.sole
    assert_equal [ [ @quality.id, 5 ] ], evaluation.rating_qualities.pluck(:quality_id, :score)
  end

  test "superseded and missing ratings finish without assessment, and the current version receives baseline scores" do
    first = submit(expressions: [ "Dread builds slowly." ])
    replacement = revise(first)
    Job.enqueue!(Ratings::Rating.maximum(:id) + 1)

    3.times { perform_next }

    assert_empty jobs.unfinished
    assert jobs.all?(&:succeeded?)
    assert_empty first.rating_quality_evals
    evaluation = replacement.rating_quality_evals.sole
    assert_empty evaluation.output.fetch("calls")
    assert_equal [ [ @quality.id, 2 ] ], evaluation.rating_qualities.pluck(:quality_id, :score)
  end

  test "a provider timeout leaves a failed job and no partial scores or pending retry" do
    rating = submit(expressions: [ "Dread builds slowly." ])
    stub_provider { |**| raise TypeSafeClient::Error.new(reason: :timeout, request_sent: true) }

    perform_next

    assert_empty jobs.unfinished
    assert_includes jobs.sole.error, "(timeout)"
    assert_empty rating.rating_quality_evals
    assert_empty rating.rating_qualities
  end

  private

  def submit(value: Ratings::Rating::Values::BRILLIANT, expressions: [])
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id, value:, expression_texts: expressions)
  end

  def revise(rating)
    Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: rating.id, value: Ratings::Rating::Values::BRILLIANT)
  end

  def jobs
    GoodJob::Job.where(queue_name: "ratings_assessment")
  end

  def perform_next
    jobs.perform_with_lock(lock_id: SecureRandom.uuid, lock_strategy: :skiplocked)
  end

  def stub_provider(&answer)
    client = Object.new
    client.define_singleton_method(:answer) { |**request| answer.call(**request) }
    client.define_singleton_method(:configuration) { { "model" => "jev-1.14.0" } }
    TypeSafeClient.define_singleton_method(:new) { |**| client }
  end
end
