class UsePolymorphicCommunityReportSources < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :community_reports, name: "community_reports_single_source"
    remove_check_constraint :community_reports, name: "community_reports_resolution_has_redacted_evidence"

    execute <<~SQL
      ALTER TABLE community_reports
        ALTER COLUMN reportable_type DROP EXPRESSION,
        ALTER COLUMN reportable_id DROP EXPRESSION
    SQL
    remove_columns :community_reports, :curation_source_id, :comment_content_source_id
    add_check_constraint :community_reports, "(reportable_type IS NULL) = (reportable_id IS NULL)",
      name: "community_reports_reportable_pair"
    add_redacted_evidence_check("reportable_type, reportable_id")

    # Database cascades also run these triggers when Rails never loads the source.
    execute <<~SQL
      CREATE FUNCTION nullify_community_report_source() RETURNS trigger
        LANGUAGE plpgsql AS $$
      BEGIN
        UPDATE public.community_reports
          SET reportable_type = NULL, reportable_id = NULL
          WHERE reportable_type = TG_ARGV[0] AND reportable_id = OLD.id;
        RETURN NULL;
      END;
      $$;

      CREATE TRIGGER nullify_community_report_source
        AFTER DELETE ON posts FOR EACH ROW
        EXECUTE FUNCTION nullify_community_report_source('Community::Post');

      CREATE TRIGGER nullify_community_report_source
        AFTER DELETE ON comment_contents FOR EACH ROW
        EXECUTE FUNCTION nullify_community_report_source('Community::CommentContent');
    SQL
  end

  def down
    if select_value(<<~SQL)
      SELECT EXISTS (
        SELECT FROM community_reports WHERE reportable_type NOT IN ('Community::Post', 'Community::CommentContent')
      )
    SQL
      raise ActiveRecord::IrreversibleMigration, "A report source uses a type the previous schema cannot store"
    end

    execute <<~SQL
      DROP TRIGGER nullify_community_report_source ON comment_contents;
      DROP TRIGGER nullify_community_report_source ON posts;
      DROP FUNCTION nullify_community_report_source();
    SQL

    add_reference :community_reports, :curation_source, foreign_key: { to_table: :posts, on_delete: :nullify, deferrable: :deferred }
    add_reference :community_reports, :comment_content_source, foreign_key: { to_table: :comment_contents, on_delete: :nullify, deferrable: :deferred }
    execute <<~SQL
      UPDATE community_reports
        SET curation_source_id = CASE WHEN reportable_type = 'Community::Post' THEN reportable_id END,
            comment_content_source_id = CASE WHEN reportable_type = 'Community::CommentContent' THEN reportable_id END
        WHERE reportable_id IS NOT NULL
    SQL
    # Check the backfilled foreign keys before altering the table again.
    execute "SET CONSTRAINTS ALL IMMEDIATE"
    remove_check_constraint :community_reports, name: "community_reports_reportable_pair"
    remove_check_constraint :community_reports, name: "community_reports_resolution_has_redacted_evidence"
    remove_columns :community_reports, :reportable_type, :reportable_id
    add_column :community_reports, :reportable_type, :virtual, type: :string, stored: true, as: <<~SQL.squish
      CASE WHEN curation_source_id IS NOT NULL THEN 'Community::Post'
           WHEN comment_content_source_id IS NOT NULL THEN 'Community::CommentContent' END
    SQL
    add_column :community_reports, :reportable_id, :virtual, type: :bigint, stored: true,
      as: "COALESCE(curation_source_id, comment_content_source_id)"
    add_index :community_reports, [ :reportable_type, :reportable_id ]
    add_index :community_reports, [ :reporter_id, :reportable_type, :reportable_id ], unique: true,
      where: "status IN ('pending', 'escalated')", name: "one_open_community_report_per_reporter_and_source"
    add_check_constraint :community_reports, "num_nonnulls(curation_source_id, comment_content_source_id) <= 1",
      name: "community_reports_single_source"
    add_redacted_evidence_check("curation_source_id, comment_content_source_id")
  end

  private

  def add_redacted_evidence_check(source_columns)
    add_check_constraint :community_reports, <<~SQL.squish, name: "community_reports_resolution_has_redacted_evidence"
      (status = 'resolved'
        AND resolved_at IS NOT NULL
        AND resolution_outcome IS NOT NULL
        AND resolution_summary IS NOT NULL
        AND num_nonnulls(reporter_id, reported_member_id, #{source_columns},
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
