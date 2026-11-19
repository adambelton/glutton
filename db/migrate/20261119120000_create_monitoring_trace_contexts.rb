class CreateMonitoringTraceContexts < ActiveRecord::Migration[8.1]
  def up
    create_table :monitoring_trace_contexts do |t|
      t.references :domain_event, type: :uuid, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :rating, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :traceparent, null: false
      t.check_constraint "num_nonnulls(domain_event_id, rating_id) = 1", name: "monitoring_trace_context_one_source"
    end

    # Preserve contexts in checkouts that ran the earlier PR migration.
    if column_exists?(:domain_events, :traceparent)
      execute <<~SQL
        INSERT INTO monitoring_trace_contexts (domain_event_id, traceparent)
        SELECT id, traceparent FROM domain_events WHERE traceparent IS NOT NULL
      SQL
      remove_column :domain_events, :traceparent
    end
    if column_exists?(:ratings, :traceparent)
      execute <<~SQL
        INSERT INTO monitoring_trace_contexts (rating_id, traceparent)
        SELECT id, traceparent FROM ratings WHERE traceparent IS NOT NULL
      SQL
      remove_column :ratings, :traceparent
    end
  end

  def down
    drop_table :monitoring_trace_contexts
  end
end
