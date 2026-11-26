class CreateCommunityReports < ActiveRecord::Migration[8.1]
  def change
    create_table :community_reports do |t|
      # Account deletion can clear both the member and source references in the same cascade.
      # Check the source keys after both actions have run.
      t.references :curation_source, foreign_key: { to_table: :posts, on_delete: :nullify, deferrable: :deferred }
      t.references :comment_content_source, foreign_key: { to_table: :comment_contents, on_delete: :nullify, deferrable: :deferred }
      t.virtual :reportable_type, type: :string, stored: true, as: <<~SQL.squish
        CASE WHEN curation_source_id IS NOT NULL THEN 'Community::Post'
             WHEN comment_content_source_id IS NOT NULL THEN 'Community::CommentContent' END
      SQL
      t.virtual :reportable_id, type: :bigint, stored: true, as: "COALESCE(curation_source_id, comment_content_source_id)"
      t.references :reporter, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :reported_member, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :part, null: false
      t.string :reason, null: false
      t.text :explanation
      t.text :evidence_text, null: false
      t.jsonb :identity_snapshot, null: false
      t.string :status, null: false, default: "pending"
      t.integer :priority, null: false
      t.timestamps

      t.index [ :reportable_type, :reportable_id ]
      t.index [ :priority, :created_at, :id ], name: "index_community_reports_for_review"
      t.index [ :reporter_id, :reportable_type, :reportable_id, :part ], unique: true,
        where: "status IN ('pending', 'escalated')", name: "one_open_community_report_per_reporter_and_part"
      t.check_constraint "num_nonnulls(curation_source_id, comment_content_source_id) <= 1", name: "community_reports_single_source"
      t.check_constraint "status IN ('pending', 'escalated')", name: "community_reports_supported_status"
    end
  end
end
