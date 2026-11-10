require "test_helper"

class Registry::LoadQualityVocabularyTest < ActiveSupport::TestCase
  setup do
    Registry::QualityCategory.delete_all
  end

  test "initial seed persists the exact retained vocabulary and nine category defaults" do
    baseline = JSON.parse(Rails.root.join("docs/film_qualities/vocabulary.json").read)
    defaults = YAML.load_file(Rails.root.join("config/quality_categories.yml"))

    assert_no_difference [ "Registry::Film.count", "Registry::FilmQuality.count", "Library::LibraryFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
      load Rails.root.join("db/seeds.rb")
      assert_equal 235, Registry::Quality.count
      assert_equal 9, Registry::QualityCategory.count
      baseline.fetch("qualities").each do |expected|
        quality = Registry::Quality.find_by!(name: expected.fetch("name"))
        assert_equal expected.fetch("match_rule"), quality.match_rule
        assert_equal expected.fetch("not_sufficient"), quality.not_sufficient
        assert_equal expected.fetch("facet"), quality.quality_category.name
      end
      defaults.each do |attributes|
        category = Registry::QualityCategory.find_by!(name: attributes.fetch("name"))
        assert_equal attributes.fetch("maximum_qualities"), category.maximum_qualities
        assert_equal 1, category.weight
      end
    end
  end

  test "late storage failure rolls back all initial categories and qualities" do
    last = YAML.load_file(Rails.root.join("config/quality_vocabulary.yml")).last
    connection = ActiveRecord::Base.connection
    connection.add_check_constraint :qualities, "name <> #{connection.quote(last.fetch('name'))}", name: "test_seed_failure"

    assert_no_difference [ "Registry::Quality.count", "Registry::QualityCategory.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) do
        Registry::Quality.transaction(requires_new: true) { Registry::QualityManagement::LoadQualityVocabulary.call }
      end
    end
  ensure
    connection.remove_check_constraint :qualities, name: "test_seed_failure" if connection
  end
end
