require "test_helper"
require "rake"

class FilmKnowledge::LoadDevelopmentSampleTest < ActiveSupport::TestCase
  def in_development
    original = Rails.env
    Rails.env = "development"
    yield
  ensure
    Rails.env = original
  end

  test "explicit sample loading repeats without changing existing films" do
    edited = Film.create!(tmdb_id: 348, title: "Local title", metadata: { original_title: "Local original", note: "Keep me" },
      release_date: Date.new(1979, 5, 24))
    unrelated = Film.create!(title: "Unrelated")
    edited_updated_at = edited.updated_at
    unrelated_updated_at = unrelated.updated_at

    in_development do
      first = FilmKnowledge::LoadDevelopmentSample.call
      assert_equal [ 348, 1091, 419430 ], first.map(&:tmdb_id)
      assert_equal [ "Local title", "The Thing", "Get Out" ], first.map(&:title)
      second = FilmKnowledge::LoadDevelopmentSample.call
      assert_equal first.map(&:id), second.map(&:id)
      assert_equal [ "Local title", "The Thing", "Get Out" ], second.map(&:title)
    end
    assert_equal 4, Film.count
    edited.reload
    unrelated.reload
    assert_equal "Local title", edited.title
    assert_equal Date.new(1979, 5, 24), edited.release_date
    assert_equal({ "original_title" => "Local original", "note" => "Keep me" }, edited.metadata)
    assert_equal edited_updated_at, edited.updated_at
    assert_equal "Unrelated", unrelated.title
    assert_equal unrelated_updated_at, unrelated.updated_at
    assert_nil Film.find_by!(tmdb_id: 1091).release_date
  end

  test "a fresh sample contains exactly three stable film identities" do
    in_development do
      assert_difference "Film.count", 3 do
        FilmKnowledge::LoadDevelopmentSample.call
      end
      assert_no_difference "Film.count" do
        assert_equal [ "Alien", "The Thing", "Get Out" ], FilmKnowledge::LoadDevelopmentSample.call.map(&:title)
      end
    end
  end

  test "actual rake command rejects test and production before writes" do
    original = Rails.env
    application = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/film_knowledge.rake")
    [ "test", "production" ].each do |environment|
      Rails.env = environment
      assert_no_difference "Film.count" do
        error = assert_raises(RuntimeError) { Rake::Task["film_knowledge:load_sample"].execute }
        assert_equal "Film sample loading is available only in development", error.message
      end
    end
  ensure
    Rails.env = original
    Rake.application = application
  end
end
