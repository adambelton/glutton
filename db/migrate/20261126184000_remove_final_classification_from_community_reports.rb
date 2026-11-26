class RemoveFinalClassificationFromCommunityReports < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :community_reports, <<~SQL.squish, name: "community_reports_resolution_has_redacted_evidence"
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
    remove_column :community_reports, :resolution_classification, :string
    add_check_constraint :community_reports, <<~SQL.squish, name: "community_reports_resolution_has_redacted_evidence"
      (status = 'resolved'
        AND resolved_at IS NOT NULL
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
        AND num_nonnulls(resolved_at, resolved_by_id, resolution_outcome, resolution_summary) = 0)
    SQL
  end
end
