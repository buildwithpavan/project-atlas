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

ActiveRecord::Schema[8.1].define(version: 2026_08_30_000014) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

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

  create_table "ai_usage_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "completion_tokens", default: 0, null: false
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.decimal "estimated_cost", precision: 10, scale: 6, default: "0.0", null: false
    t.integer "latency_ms"
    t.uuid "message_id"
    t.string "model", null: false
    t.string "operation", null: false
    t.uuid "organization_id", null: false
    t.integer "prompt_tokens", default: 0, null: false
    t.string "provider", default: "openai", null: false
    t.string "request_id"
    t.integer "total_tokens", default: 0, null: false
    t.uuid "user_id", null: false
    t.index ["conversation_id"], name: "idx_ai_usage_records_conversation"
    t.index ["message_id"], name: "idx_ai_usage_records_message"
    t.index ["organization_id", "created_at"], name: "idx_ai_usage_records_org_created", order: { created_at: :desc }
    t.index ["organization_id", "model", "created_at"], name: "idx_ai_usage_records_org_model_created", order: { created_at: :desc }
    t.index ["organization_id", "operation", "created_at"], name: "idx_ai_usage_records_org_operation_created", order: { created_at: :desc }
    t.index ["organization_id", "user_id", "created_at"], name: "idx_ai_usage_records_org_user_created", order: { created_at: :desc }
    t.index ["organization_id"], name: "idx_ai_usage_records_org"
    t.index ["request_id"], name: "idx_ai_usage_records_request_id"
  end

  create_table "conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["organization_id", "id"], name: "index_conversations_on_organization_id_and_id", unique: true
    t.index ["organization_id", "user_id", "created_at"], name: "index_conversations_on_org_user_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "document_chunks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.uuid "document_id", null: false
    t.vector "embedding", limit: 1536
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.integer "position", null: false
    t.integer "token_count"
    t.index ["document_id", "position"], name: "index_document_chunks_on_document_id_and_position", unique: true
    t.index ["organization_id"], name: "index_document_chunks_on_organization_id"
  end

  create_table "documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "checksum"
    t.integer "chunk_count", default: 0, null: false
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.string "embedding_model"
    t.text "error_message"
    t.text "extracted_text"
    t.integer "file_size", null: false
    t.string "filename", null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "organization_id", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "uploaded_by_id"
    t.index ["organization_id", "checksum"], name: "index_documents_on_organization_id_and_checksum", unique: true
    t.index ["organization_id", "created_at"], name: "index_documents_on_organization_id_and_created_at", order: { created_at: :desc }
    t.index ["organization_id", "id"], name: "index_documents_on_organization_id_and_id", unique: true
    t.index ["uploaded_by_id"], name: "index_documents_on_uploaded_by_id"
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

  create_table "idempotency_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assistant_message_id"
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.uuid "organization_id", null: false
    t.string "request_fingerprint", null: false
    t.jsonb "response_body"
    t.integer "response_status"
    t.uuid "user_id", null: false
    t.uuid "user_message_id"
    t.index ["created_at"], name: "idx_idempotency_keys_created_at"
    t.index ["organization_id", "user_id", "conversation_id", "key"], name: "idx_idempotency_keys_unique", unique: true
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

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ai_model"
    t.jsonb "citations", default: [], null: false
    t.text "content", null: false
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.integer "embedding_tokens"
    t.integer "input_tokens"
    t.integer "latency_ms"
    t.uuid "organization_id", null: false
    t.integer "output_tokens"
    t.integer "position", null: false
    t.integer "retrieval_count"
    t.float "retrieval_max_similarity"
    t.string "role", null: false
    t.index ["conversation_id", "position"], name: "index_messages_on_conversation_id_and_position", unique: true
    t.index ["organization_id"], name: "index_messages_on_organization_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "ai_monthly_cost_limit", precision: 10, scale: 2
    t.bigint "ai_monthly_token_limit"
    t.datetime "ai_quota_reserved_at"
    t.bigint "ai_quota_reserved_tokens", default: 0, null: false
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "theme_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "evidence_text"
    t.uuid "organization_id", null: false
    t.decimal "relevance_score", precision: 5, scale: 4
    t.uuid "theme_id", null: false
    t.uuid "ticket_id", null: false
    t.index ["organization_id"], name: "idx_theme_memberships_org"
    t.index ["theme_id", "ticket_id"], name: "idx_theme_memberships_unique", unique: true
    t.index ["ticket_id"], name: "idx_theme_memberships_ticket"
  end

  create_table "themes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.text "evidence_summary"
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.uuid "organization_id", null: false
    t.text "recommended_action"
    t.string "severity", default: "medium", null: false
    t.string "source_batch_id"
    t.string "status", default: "active", null: false
    t.integer "ticket_count", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "last_seen_at"], name: "index_themes_on_organization_id_and_last_seen_at", order: { last_seen_at: :desc }
    t.index ["organization_id", "severity"], name: "index_themes_on_organization_id_and_severity"
    t.index ["organization_id", "status"], name: "index_themes_on_organization_id_and_status"
    t.index ["organization_id", "ticket_count"], name: "index_themes_on_organization_id_and_ticket_count", order: { ticket_count: :desc }
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
    t.index ["organization_id", "category"], name: "index_tickets_on_org_and_category"
    t.index ["organization_id", "created_at"], name: "index_tickets_on_organization_id_and_created_at", order: { created_at: :desc }
    t.index ["organization_id", "id"], name: "index_tickets_on_organization_id_and_id", unique: true
    t.index ["organization_id", "priority"], name: "index_tickets_on_org_and_priority"
    t.index ["organization_id", "status"], name: "index_tickets_on_org_and_status"
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
  add_foreign_key "ai_usage_records", "conversations"
  add_foreign_key "ai_usage_records", "messages"
  add_foreign_key "ai_usage_records", "organizations"
  add_foreign_key "ai_usage_records", "users"
  add_foreign_key "conversations", "organizations"
  add_foreign_key "conversations", "users"
  add_foreign_key "document_chunks", "documents"
  add_foreign_key "document_chunks", "documents", column: ["organization_id", "document_id"], primary_key: ["organization_id", "id"], name: "fk_document_chunks_organization_document"
  add_foreign_key "document_chunks", "organizations"
  add_foreign_key "documents", "organizations"
  add_foreign_key "documents", "users", column: "uploaded_by_id"
  add_foreign_key "executive_summaries", "organizations"
  add_foreign_key "idempotency_keys", "conversations"
  add_foreign_key "idempotency_keys", "messages", column: "assistant_message_id"
  add_foreign_key "idempotency_keys", "messages", column: "user_message_id"
  add_foreign_key "idempotency_keys", "organizations"
  add_foreign_key "idempotency_keys", "users"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "conversations", column: ["organization_id", "conversation_id"], primary_key: ["organization_id", "id"], name: "fk_messages_organization_conversation"
  add_foreign_key "messages", "organizations"
  add_foreign_key "refresh_tokens", "refresh_tokens", column: "replaced_by_token_id", on_delete: :nullify
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "uploads"
  add_foreign_key "tickets", "uploads", column: ["organization_id", "upload_id"], primary_key: ["organization_id", "id"], name: "fk_tickets_organization_upload"
  add_foreign_key "uploads", "organizations"
  add_foreign_key "uploads", "users", column: "uploaded_by_id"
end
