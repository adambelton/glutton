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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "pending_registrations", force: :cascade do |t|
    t.bigint "guest_user_id"
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "confirmation_delivery_attempts", default: 0, null: false
    t.datetime "confirmation_delivery_attempted_at"
    t.index ["guest_user_id"], name: "index_pending_registrations_on_guest_user_id", unique: true
    t.check_constraint "confirmation_delivery_attempts >= 0 AND confirmation_delivery_attempts <= 5", name: "pending_registration_delivery_limit"
    t.check_constraint "email_address::text <> ''::text AND email_address::text = lower(email_address::text) AND email_address::text !~ '[[:space:]]'::text", name: "pending_registrations_require_canonical_email"
    t.check_constraint "password_digest::text ~ '[^[:space:]]'::text", name: "pending_registrations_require_password_digest"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_address"
    t.string "password_digest"
    t.datetime "email_confirmed_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "type::text <> 'UserRegistered'::text OR email_address IS NOT NULL AND email_address::text <> ''::text AND email_address::text = lower(email_address::text) AND email_address::text !~ '[[:space:]]'::text AND password_digest IS NOT NULL AND password_digest::text ~ '[^[:space:]]'::text AND email_confirmed_at IS NOT NULL", name: "registered_users_require_credentials"
    t.check_constraint "type::text = 'UserRegistered'::text OR email_address IS NULL AND password_digest IS NULL AND email_confirmed_at IS NULL", name: "other_users_have_no_credentials"
  end

  add_foreign_key "pending_registrations", "users", column: "guest_user_id", on_delete: :cascade
  add_foreign_key "sessions", "users"
end
