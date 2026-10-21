class CreateDomainEventDelivery < ActiveRecord::Migration[8.1]
  def change
    create_table :domain_event_streams do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :publisher, null: false
      t.string :stream_key, null: false
      t.bigint :sequence, null: false, default: 0
      t.timestamps
      t.index [ :user_id, :publisher, :stream_key ], unique: true
      t.check_constraint "sequence >= 0", name: "domain_event_stream_sequence"
      t.check_constraint "publisher <> '' AND stream_key <> ''", name: "domain_event_stream_identity"
    end

    create_table :domain_events, id: :uuid do |t|
      t.references :domain_event_stream, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :sequence, null: false
      t.string :name, null: false
      t.integer :schema_version, null: false
      t.jsonb :payload, null: false
      t.uuid :correlation_id, null: false
      t.uuid :causation_id
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
      t.index [ :domain_event_stream_id, :sequence ], unique: true
      t.check_constraint "sequence > 0 AND schema_version > 0", name: "domain_event_positive_versions"
      t.check_constraint "jsonb_typeof(payload) = 'object'", name: "domain_event_object_payload"
      t.check_constraint "name <> ''", name: "domain_event_name"
    end

    create_table :event_deliveries do |t|
      t.references :domain_event, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :subscriber, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at, null: false
      t.datetime :completed_at
      t.string :last_error_class
      t.timestamps
      t.index [ :subscriber, :domain_event_id ], unique: true
      t.index [ :subscriber, :status, :next_attempt_at ], name: "index_event_deliveries_due"
      t.check_constraint "attempts >= 0", name: "event_delivery_attempts"
      t.check_constraint "subscriber <> ''", name: "event_delivery_subscriber"
      t.check_constraint "status IN ('pending', 'processed', 'ignored', 'skipped', 'failed')", name: "event_delivery_status"
      t.check_constraint "(status IN ('processed', 'ignored', 'skipped')) = (completed_at IS NOT NULL)", name: "event_delivery_completion"
    end
  end
end
