class AddResolutionToCommunityReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :community_reports, :resolved_by, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :community_reports, :resolved_at, :datetime
    add_column :community_reports, :resolution_classification, :string
    add_column :community_reports, :resolution_outcome, :string
    add_column :community_reports, :resolution_summary, :text
    remove_index :community_reports, [ :reporter_id, :reportable_type, :reportable_id, :part ], unique: true,
      where: "status IN ('pending', 'escalated')", name: "one_open_community_report_per_reporter_and_part"
    remove_column :community_reports, :part, :string, null: false
    remove_column :community_reports, :evidence_text, :text, null: false
    add_column :community_reports, :evidence, :jsonb
    add_index :community_reports, [ :reporter_id, :reportable_type, :reportable_id ], unique: true,
      where: "status IN ('pending', 'escalated')", name: "one_open_community_report_per_reporter_and_source"
    change_column_null :community_reports, :identity_snapshot, true

    remove_check_constraint :community_reports, "status IN ('pending', 'escalated')", name: "community_reports_supported_status"
    add_check_constraint :community_reports, "status IN ('pending', 'escalated', 'resolved')", name: "community_reports_supported_status"

    add_check_constraint :community_reports, <<~SQL.squish, name: "community_reports_resolution_has_redacted_evidence"
      (status = 'resolved'
        AND resolved_at IS NOT NULL
        AND resolution_classification IS NOT NULL
        AND resolution_outcome IS NOT NULL
        AND resolution_summary IS NOT NULL
        AND num_nonnulls(reporter_id, reported_member_id, curation_source_id, comment_content_source_id,
                        evidence, identity_snapshot, explanation) = 0)
      OR
      (status IN ('pending', 'escalated')
        AND evidence IS NOT NULL
        AND jsonb_typeof(evidence) = 'object'
        AND evidence <> '{}'::jsonb
        AND identity_snapshot IS NOT NULL
        AND num_nonnulls(resolved_at, resolved_by_id, resolution_classification, resolution_outcome, resolution_summary) = 0)
    SQL
  end
end
