class CreateRatingQualityReassessmentRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_quality_reassessment_requests do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :expression_profile_revision, null: false, foreign_key: { on_delete: :cascade },
        index: { name: "index_rating_quality_reassessments_on_profile_revision" }
      t.timestamps
    end
  end
end
