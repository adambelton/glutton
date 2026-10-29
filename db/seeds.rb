# System seed retry reuses existing categories without resetting administrator tuning.
YAML.load_file(Rails.root.join("config/quality_categories.yml")).each do |attributes|
  QualityCategory.find_or_create_by!(key: attributes.fetch("key")) do |category|
    category.assign_attributes(attributes.merge("weight" => 1))
  end
end
