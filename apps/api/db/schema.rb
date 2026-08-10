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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_164451) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "family_id", null: false
    t.uuid "replaced_by_token_id"
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["family_id"], name: "index_refresh_tokens_on_family_id"
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "tickets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "customer_email"
    t.string "customer_name"
    t.text "description"
    t.uuid "organization_id", null: false
    t.string "priority"
    t.string "status"
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.uuid "upload_id", null: false
    t.index ["organization_id", "created_at"], name: "index_tickets_on_organization_id_and_created_at", order: { created_at: :desc }
    t.index ["upload_id"], name: "index_tickets_on_upload_id"
  end

  create_table "uploads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "failed_records", default: 0
    t.string "filename", null: false
    t.uuid "organization_id", null: false
    t.integer "processed_records", default: 0
    t.string "status", default: "pending", null: false
    t.integer "total_records"
    t.datetime "updated_at", null: false
    t.uuid "uploaded_by_id"
    t.index ["organization_id", "created_at"], name: "index_uploads_on_organization_id_and_created_at", order: { created_at: :desc }
    t.index ["organization_id", "id"], name: "index_uploads_on_organization_id_and_id", unique: true
    t.index ["uploaded_by_id"], name: "index_uploads_on_uploaded_by_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
  end

  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "refresh_tokens", "refresh_tokens", column: "replaced_by_token_id", on_delete: :nullify
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "uploads"
  add_foreign_key "tickets", "uploads", column: ["organization_id", "upload_id"], primary_key: ["organization_id", "id"], name: "fk_tickets_organization_upload"
  add_foreign_key "uploads", "organizations"
  add_foreign_key "uploads", "users", column: "uploaded_by_id"
end
