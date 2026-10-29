require "test_helper"

class QualityCategoryTest < ActiveSupport::TestCase
  test "category configuration is editable with explicit stale update and removal outcomes" do
    category = QualityCategory.create!(key: "new_kind", name: "New kind", maximum_qualities: 5)
    stale = QualityCategory.find(category.id)
    category.update!(name: "Revised kind", maximum_qualities: 2, weight: "0.75")
    assert_equal [ "Revised kind", 2, BigDecimal("0.75") ], [ category.reload.name, category.maximum_qualities, category.weight ]
    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(maximum_qualities: 4) }
    assert_raises(ActiveRecord::StaleObjectError) { stale.destroy! }
    removed = QualityCategory.find(category.id)
    category.remove!
    assert_raises(ActiveRecord::StaleObjectError) { removed.update!(name: "Gone") }
  end

  test "keys remain stable while names and zero limits can be edited" do
    category = quality_categories(:tone)
    assert_raises(ActiveRecord::RecordInvalid) { category.update!(key: "replacement") }
    assert category.errors.of_kind?(:key, :immutable)
    category.reload.update!(maximum_qualities: 0, weight: 0, name: "Retuned tone")
    assert_equal 0, category.reload.maximum_qualities
    assert_equal 0, category.weight
    duplicate = QualityCategory.new(key: "other", name: "retuned tone")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  test "invalid configuration is rejected by model and storage boundaries" do
    [ { maximum_qualities: -1 }, { maximum_qualities: 1.5 }, { maximum_qualities: nil },
      { weight: -0.1 }, { weight: "NaN" }, { weight: nil }, { name: " " }, { key: "UPPER CASE" } ].each do |attributes|
      category = QualityCategory.new({ key: "test", name: "Test" }.merge(attributes))
      assert_not category.valid?, attributes.inspect
      assert category.errors.full_messages.none? { |message| message.include?("Translation missing") }
    end
    [ { maximum_qualities: -1 }, { weight: -1 }, { weight: "NaN" }, { key: "invalid key" }, { name: " " } ].each do |attributes|
      assert_raises(ActiveRecord::StatementInvalid) do
        QualityCategory.transaction(requires_new: true) do
          QualityCategory.insert_all!([ { key: "invalid", name: "Invalid", **attributes } ])
        end
      end
    end
  end

  test "categories referenced by qualities cannot be removed" do
    category = quality_categories(:tone)
    quality = category.qualities.create!(name: "A quality")
    assert_raises(ActiveRecord::DeleteRestrictionError) { category.remove! }
    assert_raises(ActiveRecord::InvalidForeignKey) do
      QualityCategory.transaction(requires_new: true) { category.delete }
    end
    quality.destroy!
    category.remove!
    assert_not QualityCategory.exists?(category.id)
  end

  test "recategorisation preserves identity and evidence and rejects collisions or stale moves" do
    source = quality_categories(:tone)
    target = quality_categories(:emotional_character)
    quality = source.qualities.create!(name: "Dread")
    stale = Quality.find(quality.id)
    target.qualities.create!(name: "DREAD")
    assert_raises(ActiveRecord::RecordInvalid) { quality.recategorise!(quality_category: target) }
    assert_equal source, quality.reload.quality_category
    category = QualityCategory.create!(key: "new", name: "New")
    @film = Film.create!(title: "Quality move")
    link = @film.film_qualities.create!(quality: quality, evidence_references: [ "M1" ])
    quality.recategorise!(quality_category: category)
    assert_equal category, quality.reload.quality_category
    assert_equal quality.id, link.reload.quality_id
    assert_equal [ "M1" ], link.evidence_references
    assert_raises(ActiveRecord::StaleObjectError) { stale.recategorise!(quality_category: source) }
    assert_raises(ActiveRecord::RecordInvalid) { quality.update!(name: "Renamed") }
    assert quality.errors.of_kind?(:name, :immutable)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Quality.transaction(requires_new: true) { quality.reload.update_columns(quality_category_id: -1) }
    end
  end

  test "baseline seed is category-specific and reruns preserve tuning and do not seed qualities" do
    assert_no_difference("Quality.count") { load Rails.root.join("db/seeds.rb") }
    categories = QualityCategory.where(key: %w[subgenres tropes_and_situations themes]).index_by(&:key)
    assert_equal 2, categories.fetch("subgenres").maximum_qualities
    assert_equal 5, categories.fetch("tropes_and_situations").maximum_qualities
    assert_equal 4, categories.fetch("themes").maximum_qualities
    category = categories.fetch("themes")
    category.update!(name: "Tuned themes", maximum_qualities: 1, weight: "0.5")
    assert_no_difference([ "QualityCategory.count", "Quality.count" ]) { load Rails.root.join("db/seeds.rb") }
    assert_equal [ "Tuned themes", 1, BigDecimal("0.5") ], [ category.reload.name, category.maximum_qualities, category.weight ]
  end
end
