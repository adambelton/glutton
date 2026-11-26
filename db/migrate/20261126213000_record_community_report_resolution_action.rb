class RecordCommunityReportResolutionAction < ActiveRecord::Migration[8.1]
  def change
    add_column :community_reports, :resolution_action, :string
    add_check_constraint :community_reports, <<~SQL.squish, name: "community_reports_resolution_action_valid"
      resolution_action IS NULL OR
        (status = 'resolved' AND resolution_outcome = 'violation_confirmed' AND
          (resolution_action = 'delete_record' OR resolution_action ~ '^delete_attribute:[a-z][a-z0-9_]*$'))
    SQL
  end
end
