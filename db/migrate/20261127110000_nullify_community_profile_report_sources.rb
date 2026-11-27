class NullifyCommunityProfileReportSources < ActiveRecord::Migration[8.1]
  def up
    replace_source_function("(to_jsonb(OLD) ->> COALESCE(TG_ARGV[1], 'id'))::bigint")
    execute <<~SQL
      CREATE TRIGGER nullify_community_report_source
        AFTER DELETE ON community_users FOR EACH ROW
        EXECUTE FUNCTION nullify_community_report_source('Community::CommunityUser', 'user_id');
    SQL
  end

  def down
    if select_value(<<~SQL)
      SELECT EXISTS (
        SELECT 1 FROM community_reports
        WHERE reportable_type = 'Community::CommunityUser' OR resolution_action = 'delete_attribute:community_username'
      )
    SQL
      raise ActiveRecord::IrreversibleMigration, "Existing username reports need this source and its cleanup trigger"
    end

    execute "DROP TRIGGER nullify_community_report_source ON community_users"
    replace_source_function("OLD.id")
  end

  private

  def replace_source_function(source_id)
    execute <<~SQL
      CREATE OR REPLACE FUNCTION nullify_community_report_source() RETURNS trigger
        LANGUAGE plpgsql AS $$
      BEGIN
        UPDATE public.community_reports
          SET reportable_type = NULL, reportable_id = NULL
          WHERE reportable_type = TG_ARGV[0] AND reportable_id = #{source_id};
        RETURN NULL;
      END;
      $$;
    SQL
  end
end
