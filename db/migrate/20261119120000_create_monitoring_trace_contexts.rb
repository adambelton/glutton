class CreateMonitoringTraceContexts < ActiveRecord::Migration[8.1]
  def change
    create_table :monitoring_trace_contexts do |t|
      t.references :domain_event, type: :uuid, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :rating, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :traceparent, null: false
      t.check_constraint "num_nonnulls(domain_event_id, rating_id) = 1", name: "monitoring_trace_context_one_source"
    end
  end
end
