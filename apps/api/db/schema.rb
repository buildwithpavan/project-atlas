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

ActiveRecord::Schema[8.1].define(version: 2026_08_11_101929) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_analyses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "bug_report"
    t.string "category"
    t.decimal "confidence", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.text "error_message"
    t.boolean "feature_request"
    t.boolean "knowledge_gap"
    t.uuid "organization_id", null: false
    t.datetime "processed_at"
    t.string "sentiment"
    t.string "status", default: "pending", null: false
    t.text "summary"
    t.uuid "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "created_at"], name: "index_ai_analyses_on_organization_id_and_created_at", order: { created_at: :desc }
    t.index ["status"], name: "index_ai_analyses_on_status_partial", where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying])::text[]))"
    t.index ["ticket_id"], name: "index_ai_analyses_on_ticket_id", unique: true
  end

  create_table "executive_summaries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "analyzed_ticket_count", null: false
    t.jsonb "attention_items", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.jsonb "key_findings", default: [], null: false
    t.uuid "organization_id", null: false
    t.jsonb "recommended_actions", default: [], null: false
    t.text "summary", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_executive_summaries_on_organization_id", unique: true
  end

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
    t.index ["organization_id", "id"], name: "index_tickets_on_organization_id_and_id", unique: true
    t.index ["upload_id"], name: "index_tickets_on_upload_id"
  end

  create_table "uploads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_analyses", "organizations"
  add_foreign_key "ai_analyses", "tickets"
  add_foreign_key "ai_analyses", "tickets", column: ["organization_id", "ticket_id"], primary_key: ["organization_id", "id"], name: "fk_ai_analyses_organization_ticket"
  add_foreign_key "executive_summaries", "organizations"
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
