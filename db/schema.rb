# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_29_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "domain_event_streams", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "publisher", null: false
    t.string "stream_key", null: false
    t.bigint "sequence", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "publisher", "stream_key"], name: "idx_on_user_id_publisher_stream_key_dbea133667", unique: true
    t.index ["user_id"], name: "index_domain_event_streams_on_user_id"
    t.check_constraint "publisher::text <> ''::text AND stream_key::text <> ''::text", name: "domain_event_stream_identity"
    t.check_constraint "sequence >= 0", name: "domain_event_stream_sequence"
  end

  create_table "domain_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "domain_event_stream_id", null: false
    t.bigint "sequence", null: false
    t.string "name", null: false
    t.integer "schema_version", null: false
    t.jsonb "payload", null: false
    t.uuid "correlation_id", null: false
    t.uuid "causation_id"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.index ["domain_event_stream_id", "sequence"], name: "index_domain_events_on_domain_event_stream_id_and_sequence", unique: true
    t.index ["domain_event_stream_id"], name: "index_domain_events_on_domain_event_stream_id"
    t.check_constraint "jsonb_typeof(payload) = 'object'::text", name: "domain_event_object_payload"
    t.check_constraint "name::text <> ''::text", name: "domain_event_name"
    t.check_constraint "sequence > 0 AND schema_version > 0", name: "domain_event_positive_versions"
  end

  create_table "event_deliveries", force: :cascade do |t|
    t.uuid "domain_event_id", null: false
    t.string "subscriber", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "next_attempt_at", null: false
    t.datetime "completed_at"
    t.string "last_error_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_event_id"], name: "index_event_deliveries_on_domain_event_id"
    t.index ["subscriber", "domain_event_id"], name: "index_event_deliveries_on_subscriber_and_domain_event_id", unique: true
    t.index ["subscriber", "status", "next_attempt_at"], name: "index_event_deliveries_due"
    t.check_constraint "(status::text = ANY (ARRAY['processed'::character varying, 'ignored'::character varying, 'skipped'::character varying]::text[])) = (completed_at IS NOT NULL)", name: "event_delivery_completion"
    t.check_constraint "attempts >= 0", name: "event_delivery_attempts"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processed'::character varying, 'ignored'::character varying, 'skipped'::character varying, 'failed'::character varying]::text[])", name: "event_delivery_status"
    t.check_constraint "subscriber::text <> ''::text", name: "event_delivery_subscriber"
  end

  create_table "film_qualities", force: :cascade do |t|
    t.bigint "film_id", null: false
    t.bigint "quality_id", null: false
    t.jsonb "evidence_references", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id", "quality_id"], name: "index_film_qualities_on_film_id_and_quality_id", unique: true
    t.index ["film_id"], name: "index_film_qualities_on_film_id"
    t.index ["quality_id"], name: "index_film_qualities_on_quality_id"
    t.check_constraint "jsonb_typeof(evidence_references) = 'array'::text AND jsonb_array_length(evidence_references) > 0", name: "film_qualities_evidence_present"
  end

  create_table "films", force: :cascade do |t|
    t.string "title", null: false
    t.date "release_date"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "tmdb_id"
    t.jsonb "source_context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tmdb_id"], name: "index_films_on_tmdb_id", unique: true
    t.check_constraint "jsonb_typeof(metadata) = 'object'::text", name: "films_metadata_is_object"
    t.check_constraint "jsonb_typeof(source_context) = 'object'::text", name: "films_source_context_object"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.index ["created_at", "id"], name: "index_good_job_batches_on_created_at_and_id", order: :desc
    t.index ["finished_at"], name: "index_good_job_batches_on_finished_at", where: "(finished_at IS NOT NULL)"
  end

  create_table "good_job_concurrency_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "job_id", null: false
    t.uuid "locked_by_id"
    t.integer "state", limit: 2, null: false
    t.text "key", null: false
    t.index ["job_id"], name: "index_good_job_concurrency_claims_on_job_id"
    t.index ["key", "job_id"], name: "index_good_job_concurrency_claims_on_key_and_job_id", unique: true
    t.index ["key", "state", "created_at"], name: "index_good_job_concurrency_claims_for_promotion"
    t.index ["locked_by_id"], name: "index_good_job_concurrency_claims_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
    t.index ["scheduled_at"], name: "index_good_job_executions_on_scheduled_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id_unfinished", where: "((batch_callback_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id_unfinished", where: "((batch_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, order: { cron_at: "DESC NULLS LAST" }, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class", "finished_at"], name: "index_good_jobs_on_discarded_job_class", where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "priority", "created_at"], name: "index_good_jobs_dequeue_by_queue", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "priority", "scheduled_at"], name: "index_good_jobs_dequeue_by_queue_scheduled_at", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "library_films", force: :cascade do |t|
    t.string "type", null: false
    t.bigint "user_id", null: false
    t.bigint "film_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id"], name: "index_library_films_on_film_id"
    t.index ["user_id", "film_id"], name: "index_library_films_on_user_id_and_film_id", unique: true
  end

  create_table "pending_registrations", force: :cascade do |t|
    t.bigint "guest_user_id"
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "confirmation_delivery_attempts", default: 0, null: false
    t.datetime "confirmation_delivery_attempted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_user_id"], name: "index_pending_registrations_on_guest_user_id", unique: true
    t.check_constraint "confirmation_delivery_attempts >= 0 AND confirmation_delivery_attempts <= 5", name: "pending_registration_delivery_limit"
    t.check_constraint "email_address::text <> ''::text AND email_address::text = lower(email_address::text) AND email_address::text !~ '[[:space:]]'::text", name: "pending_registrations_require_canonical_email"
    t.check_constraint "password_digest::text ~ '[^[:space:]]'::text", name: "pending_registrations_require_password_digest"
  end

  create_table "qualities", force: :cascade do |t|
    t.bigint "quality_category_id", null: false
    t.string "name", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "quality_category_id, lower((name)::text)", name: "qualities_category_name", unique: true
    t.index ["quality_category_id"], name: "index_qualities_on_quality_category_id"
    t.check_constraint "name::text = btrim(name::text) AND name::text <> ''::text", name: "qualities_name_present"
  end

  create_table "quality_categories", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.integer "maximum_qualities", default: 3, null: false
    t.decimal "weight", precision: 8, scale: 3, default: "1.0", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "quality_categories_name", unique: true
    t.index ["key"], name: "index_quality_categories_on_key", unique: true
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]*$'::text", name: "quality_categories_key"
    t.check_constraint "maximum_qualities >= 0", name: "quality_categories_maximum"
    t.check_constraint "name::text = btrim(name::text) AND name::text <> ''::text", name: "quality_categories_name_present"
    t.check_constraint "weight >= 0::numeric AND weight <> 'NaN'::numeric", name: "quality_categories_weight"
  end

  create_table "rating_expressions", force: :cascade do |t|
    t.bigint "rating_id", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rating_id"], name: "index_rating_expressions_on_rating_id"
    t.check_constraint "char_length(text) <= 2000", name: "rating_expressions_text_length"
  end

  create_table "rating_films", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "film_id", null: false
    t.boolean "dismissed", default: false, null: false
    t.boolean "held", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id"], name: "index_rating_films_on_film_id"
    t.index ["user_id", "film_id"], name: "index_rating_films_on_user_id_and_film_id", unique: true
  end

  create_table "ratings", force: :cascade do |t|
    t.bigint "rating_film_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rating_film_id", "id"], name: "index_ratings_on_rating_film_id_and_id"
    t.check_constraint "value::text = ANY (ARRAY['brilliant'::character varying, 'i_enjoyed_that'::character varying, 'not_for_me'::character varying, 'garbage'::character varying]::text[])", name: "ratings_value_allowed"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "type", null: false
    t.string "email_address"
    t.string "password_digest"
    t.datetime "email_confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "type::text <> 'UserRegistered'::text OR email_address IS NOT NULL AND email_address::text <> ''::text AND email_address::text = lower(email_address::text) AND email_address::text !~ '[[:space:]]'::text AND password_digest IS NOT NULL AND password_digest::text ~ '[^[:space:]]'::text AND email_confirmed_at IS NOT NULL", name: "registered_users_require_credentials"
    t.check_constraint "type::text = 'UserRegistered'::text OR email_address IS NULL AND password_digest IS NULL AND email_confirmed_at IS NULL", name: "other_users_have_no_credentials"
  end

  add_foreign_key "domain_event_streams", "users", on_delete: :cascade
  add_foreign_key "domain_events", "domain_event_streams", on_delete: :cascade
  add_foreign_key "event_deliveries", "domain_events", on_delete: :cascade
  add_foreign_key "film_qualities", "films"
  add_foreign_key "film_qualities", "qualities"
  add_foreign_key "library_films", "films"
  add_foreign_key "library_films", "users", on_delete: :cascade
  add_foreign_key "pending_registrations", "users", column: "guest_user_id", on_delete: :cascade
  add_foreign_key "qualities", "quality_categories"
  add_foreign_key "rating_expressions", "ratings", on_delete: :cascade
  add_foreign_key "rating_films", "films"
  add_foreign_key "rating_films", "users", on_delete: :cascade
  add_foreign_key "ratings", "rating_films", on_delete: :cascade
  add_foreign_key "sessions", "users"
end
