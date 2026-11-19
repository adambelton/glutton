class AddWorkflowTraceContext < ActiveRecord::Migration[8.1]
  def change
    add_column :domain_events, :traceparent, :string
    add_column :ratings, :traceparent, :string
  end
end
