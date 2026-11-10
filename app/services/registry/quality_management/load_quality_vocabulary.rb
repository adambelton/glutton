module Registry
  module QualityManagement
    class LoadQualityVocabulary
      def self.call
        Quality.transaction do
          YAML.load_file(Rails.root.join("config/quality_categories.yml")).each do |attributes|
            QualityCategory.create!(attributes.merge("weight" => 1))
          end

          YAML.load_file(Rails.root.join("config/quality_vocabulary.yml")).map do |attributes|
            quality_category = QualityCategory.find_by!(name: attributes.fetch("quality_category_name"))
            Quality.create!(attributes.except("quality_category_name").merge("quality_category" => quality_category))
          end
        end
      end
    end
  end
end
