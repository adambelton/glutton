require "test_helper"

class QualityTest < ActiveSupport::TestCase
  def attributes
    { name: "Source supported", quality_category: quality_categories(:tone),
      match_rule: "The context establishes the characteristic.", not_sufficient: "A title alone is insufficient." }
  end

  test "names remain immutable and definitions are editable with stale write protection" do
    quality = Quality.create!(attributes)
    stale = Quality.find(quality.id)
    quality.update!(match_rule: "Revised meaning within concept", not_sufficient: "Revised exclusion")
    assert_equal "Revised meaning within concept", quality.reload.match_rule
    assert_equal "Revised exclusion", quality.not_sufficient
    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(match_rule: "Lost edit") }
    assert_raises(ActiveRecord::RecordInvalid) { quality.update!(name: "Replacement") }
    assert quality.errors.of_kind?(:name, :immutable)
    assert_raises(ActiveModel::UnknownAttributeError) { Quality.new(attributes.merge(key: "unneeded")) }
    legacy = Quality.create!(name: "Legacy", quality_category: quality_categories(:tone))
    assert_nil legacy.match_rule
    assert_nil legacy.not_sufficient
  end

  test "supplied definitions and exclusions must form a complete nonblank pair" do
    [ { match_rule: nil }, { match_rule: " " }, { not_sufficient: nil }, { not_sufficient: "\t" } ].each do |changes|
      quality = Quality.new(attributes.merge(changes))
      assert_not quality.valid?
      assert quality.errors.of_kind?(changes.keys.first, :blank)
      assert quality.errors.full_messages.none? { |message| message.match?(/translation missing/i) }
      assert_raises(ActiveRecord::StatementInvalid) do
        Quality.transaction(requires_new: true) do
          Quality.insert_all!([ attributes.except(:quality_category).merge(quality_category_id: quality_categories(:tone).id).merge(changes) ])
        end
      end
    end
  end
end
