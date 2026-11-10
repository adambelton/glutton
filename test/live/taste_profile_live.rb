require "test_helper"
require "dotenv"

# Opt-in with bin/rails test test/live/taste_profile_live.rb.
class TasteProfileLiveTest < ActiveSupport::TestCase
  class BudgetedResponses
    RESERVE_USD = BigDecimal("0.10")
    MAX_REQUEST_BYTES = 20_000
    MAX_CALLS = 3

    attr_reader :usage, :attempts

    def initialize(responses, budget_usd:)
      @responses, @budget_usd = responses, budget_usd
      @attempts = 0
      @usage = []
    end

    def create(**request)
      unless request.fetch(:model) == "gpt-6.1-terra" && request.fetch(:max_output_tokens) <= 3_200 &&
          JSON.generate(request).bytesize <= MAX_REQUEST_BYTES
        raise "Live request exceeded the bounds used for its cost reserve"
      end
      raise "Live test spend limit reached" if @attempts >= MAX_CALLS || (@attempts + 1) * RESERVE_USD > @budget_usd

      # Count the reservation even if the provider times out.
      @attempts += 1
      response = @responses.create(**request)
      @usage << [ response.model, response.usage&.input_tokens, response.usage&.output_tokens ]
      response
    end
  end

  setup do
    skip "Set TASTE_PROFILE_LIVE_BUDGET_USD to opt into paid requests" unless ENV.key?("TASTE_PROFILE_LIVE_BUDGET_USD")

    settings = Dotenv.parse(Rails.root.join(".env.development").to_s).merge(ENV.to_h)
    openai = AiConfiguration.openai_client(env: settings)
    assert openai, "An OpenAI project API key is required"
    budget = BigDecimal(ENV.fetch("TASTE_PROFILE_LIVE_BUDGET_USD"))
    assert budget.between?(BudgetedResponses::RESERVE_USD * BudgetedResponses::MAX_CALLS, 2),
      "The live suite needs $0.30 of reserve and supports an approved cap of at most $2"
    @responses = BudgetedResponses.new(openai.responses, budget_usd: budget)
    @client = Struct.new(:responses).new(@responses)
    @user = Identity::UserGuest.create!
  end

  teardown do
    if @responses
      puts "Live OpenAI attempts: #{@responses.attempts}; model, input tokens, output tokens: #{@responses.usage.inspect}"
    end
  end

  test "citations follow paraphrases and identical rating revisions while deleted evidence is excluded" do
    quiet = submit("Silent House", "I loved the long silences because they made each return to the house feel less safe.")
    gore = submit("Painted Bones", "I disliked the graphic gore because it broke the tension.")
    initial = refresh
    assert_equal [ quiet.id, gore.id ].sort, cited_ids(initial).sort

    identical = revise(quiet, quiet.notes)
    assert_equal initial, refresh
    assert_equal 1, @responses.attempts

    paraphrased = revise(gore, "The graphic bloodshed pulled me out of the suspense, and I didn't enjoy it.")
    edited = refresh
    assert_equal [ identical.id, paraphrased.id ].sort, cited_ids(edited).sort
    assert_equal [ quiet.id, gore.id ].sort, cited_ids(initial).sort

    revise(paraphrased, nil)
    removed = refresh
    assert_equal [ identical.id ], cited_ids(removed)
    assert_equal 3, @responses.attempts

    revise(identical, nil)
    assert_empty refresh.profile
    assert_equal 3, @responses.attempts
  end

  private

  def submit(title, notes)
    film = Registry::Film.create!(title:)
    Ratings::RatingFilm.create!(user: @user, film:).submit_rating!(value: "pretty_good", notes:)
  end

  def revise(rating, notes)
    rating.rating_film.revise_rating!(previous_rating_id: rating.id, value: "not_for_me", notes:)
  end

  def refresh
    revision = Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: @client, tracer_provider: nil)
    puts "Live profile #{revision.id}: #{revision.profile}"
    revision
  end

  def cited_ids(revision)
    notes = revision.taste_profile_revision_eval.output.fetch("evidence").index_by { |note| note.fetch("rating_id") }
    revision.annotations.flat_map do |annotation|
      annotation.fetch("citations").map do |citation|
        id, start, ending = citation.values_at("rating_id", "start_offset", "end_offset")
        quote = notes.fetch(id).fetch("text")[start...ending]
        assert quote.present?
        puts "  #{annotation.fetch('claim')} [rating #{id}]: #{quote.inspect}"
        id
      end
    end.uniq
  end
end
