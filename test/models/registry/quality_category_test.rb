require "test_helper"

class Registry::QualityCategoryTest < ActiveSupport::TestCase
  test "category configuration is editable with explicit stale update and removal outcomes" do
    category = Registry::QualityCategory.create!(name: "New kind", maximum_qualities: 5)
    stale = Registry::QualityCategory.find(category.id)
    category.update!(name: "Revised kind", maximum_qualities: 2, weight: "0.75")
    assert_equal [ "Revised kind", 2, BigDecimal("0.75") ], [ category.reload.name, category.maximum_qualities, category.weight ]
    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(maximum_qualities: 4) }
    assert_raises(ActiveRecord::StaleObjectError) { stale.destroy! }
    removed = Registry::QualityCategory.find(category.id)
    category.remove!
    assert_raises(ActiveRecord::StaleObjectError) { removed.update!(name: "Gone") }
  end

  test "names and zero limits can be edited without changing associated qualities" do
    category = quality_categories(:tone)
    quality = category.qualities.create!(name: "Retained quality")
    assert_raises(ActiveModel::UnknownAttributeError) { Registry::QualityCategory.new(name: "No key", key: "unneeded") }
    category.reload.update!(maximum_qualities: 0, weight: 0, name: "Retuned tone")
    assert_equal 0, category.reload.maximum_qualities
    assert_equal 0, category.weight
    assert_equal category.id, quality.reload.quality_category_id
    assert_equal "Retuned tone", quality.quality_category.name
    duplicate = Registry::QualityCategory.new(name: "retuned tone")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  test "invalid configuration is rejected by model and storage boundaries" do
    [ { maximum_qualities: -1 }, { maximum_qualities: 1.5 }, { maximum_qualities: nil },
      { weight: -0.1 }, { weight: "NaN" }, { weight: nil }, { name: " " } ].each do |attributes|
      category = Registry::QualityCategory.new({ name: "Test" }.merge(attributes))
      assert_not category.valid?, attributes.inspect
      assert category.errors.full_messages.none? { |message| message.include?("Translation missing") }
    end
    [ { maximum_qualities: -1 }, { weight: -1 }, { weight: "NaN" }, { name: " " } ].each do |attributes|
      assert_raises(ActiveRecord::StatementInvalid) do
        Registry::QualityCategory.transaction(requires_new: true) do
          Registry::QualityCategory.insert_all!([ { name: "Invalid", **attributes } ])
        end
      end
    end
  end

  test "categories referenced by qualities cannot be removed" do
    category = quality_categories(:tone)
    quality = category.qualities.create!(name: "A quality")
    assert_raises(ActiveRecord::DeleteRestrictionError) { category.remove! }
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Registry::QualityCategory.transaction(requires_new: true) { category.delete }
    end
    quality.destroy!
    category.remove!
    assert_not Registry::QualityCategory.exists?(category.id)
  end

  test "recategorisation preserves identity and film associations and rejects collisions or stale moves" do
    source = quality_categories(:tone)
    target = quality_categories(:emotional_character)
    quality = source.qualities.create!(name: "Dread")
    stale = Registry::Quality.find(quality.id)
    target.qualities.create!(name: "DREAD")
    assert_raises(ActiveRecord::RecordInvalid) { quality.recategorise!(quality_category: target) }
    assert_equal source, quality.reload.quality_category
    category = Registry::QualityCategory.create!(name: "New")
    @film = Registry::Film.create!(title: "Quality move")
    link = @film.film_qualities.create!(quality: quality)
    quality.recategorise!(quality_category: category)
    assert_equal category, quality.reload.quality_category
    assert_equal quality.id, link.reload.quality_id
    assert_raises(ActiveRecord::StaleObjectError) { stale.recategorise!(quality_category: source) }
    assert_raises(ActiveRecord::RecordInvalid) { quality.update!(name: "Renamed") }
    assert quality.errors.of_kind?(:name, :immutable)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Registry::Quality.transaction(requires_new: true) { quality.reload.update_columns(quality_category_id: -1) }
    end
  end

  test "initial seed uses category-specific defaults" do
    Registry::QualityCategory.delete_all
    load Rails.root.join("db/seeds.rb")
    categories = Registry::QualityCategory.all.index_by(&:name)
    assert_equal 2, categories.fetch("Subgenres").maximum_qualities
    assert_equal 5, categories.fetch("Tropes and situations").maximum_qualities
    assert_equal 4, categories.fetch("Themes").maximum_qualities
  end
end
