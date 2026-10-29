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

ActiveRecord::Schema[8.1].define(version: 2026_10_29_120000) do
  create_table "access_codes", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.integer "channel", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.string "destination", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_access_codes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_access_codes_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
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

  create_table "ai_reviews", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_message"
    t.text "headline"
    t.text "mistake"
    t.text "next_focus"
    t.datetime "rated_at"
    t.integer "rating"
    t.text "rating_comment"
    t.text "raw_response"
    t.integer "reviewer_id"
    t.datetime "revised_at"
    t.datetime "seen_at"
    t.integer "status", default: 0, null: false
    t.text "strengths"
    t.integer "training_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewer_id"], name: "index_ai_reviews_on_reviewer_id"
    t.index ["training_session_id"], name: "index_ai_reviews_on_training_session_id", unique: true
  end

  create_table "allowed_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_allowed_emails_on_email", unique: true
  end

  create_table "clip_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "training_session_id", null: false
    t.string "user_agent"
    t.integer "viewer_id"
    t.index ["created_at"], name: "index_clip_accesses_on_created_at"
    t.index ["training_session_id"], name: "index_clip_accesses_on_training_session_id"
    t.index ["viewer_id"], name: "index_clip_accesses_on_viewer_id"
  end

  create_table "comebacks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "days_away"
    t.integer "reason", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_comebacks_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "learner_id", null: false
    t.datetime "learner_message_at"
    t.datetime "learner_read_at"
    t.datetime "mentor_message_at"
    t.datetime "mentors_read_at"
    t.datetime "updated_at", null: false
    t.index ["learner_id"], name: "index_conversations_on_learner_id", unique: true
  end

  create_table "diagnoses", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "level"
    t.integer "setup"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_diagnoses_on_user_id"
  end

  create_table "diagnosis_blockers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "diagnosis_id", null: false
    t.integer "kind", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_id", "kind"], name: "index_diagnosis_blockers_on_diagnosis_id_and_kind", unique: true
    t.index ["diagnosis_id"], name: "index_diagnosis_blockers_on_diagnosis_id"
  end

  create_table "instruction_steps", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "maneuver_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["maneuver_id", "position"], name: "index_instruction_steps_on_maneuver_id_and_position"
    t.index ["maneuver_id"], name: "index_instruction_steps_on_maneuver_id"
  end

  create_table "learning_modules", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "subtitle"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_learning_modules_on_code", unique: true
    t.index ["position"], name: "index_learning_modules_on_position"
  end

  create_table "maneuver_progresses", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "maneuver_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["maneuver_id"], name: "index_maneuver_progresses_on_maneuver_id"
    t.index ["user_id", "maneuver_id"], name: "index_maneuver_progresses_on_user_id_and_maneuver_id", unique: true
    t.index ["user_id"], name: "index_maneuver_progresses_on_user_id"
  end

  create_table "maneuvers", force: :cascade do |t|
    t.string "average_time"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "difficulty", default: 0, null: false
    t.integer "kind", default: 0, null: false
    t.integer "learning_module_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "prerequisite_id"
    t.boolean "requires_clip", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.text "why_now"
    t.index ["code"], name: "index_maneuvers_on_code", unique: true
    t.index ["learning_module_id"], name: "index_maneuvers_on_learning_module_id"
    t.index ["prerequisite_id"], name: "index_maneuvers_on_prerequisite_id"
    t.index ["slug"], name: "index_maneuvers_on_slug", unique: true
  end

  create_table "meetups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.decimal "latitude", precision: 9, scale: 6, null: false
    t.decimal "longitude", precision: 9, scale: 6, null: false
    t.string "note"
    t.string "place_name", null: false
    t.string "share_token", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ends_at"], name: "index_meetups_on_ends_at"
    t.index ["share_token"], name: "index_meetups_on_share_token", unique: true
    t.index ["user_id"], name: "index_meetups_on_user_id"
  end

  create_table "mentor_notes", force: :cascade do |t|
    t.integer "author_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "learner_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_mentor_notes_on_author_id"
    t.index ["learner_id"], name: "index_mentor_notes_on_learner_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "author_id"
    t.text "body", null: false
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_messages_on_author_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "skate_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "skated_on", null: false
    t.integer "training_session_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.datetime "validated_at"
    t.index ["training_session_id"], name: "index_skate_sessions_on_training_session_id", unique: true
    t.index ["user_id", "skated_on"], name: "index_skate_sessions_on_user_id_and_skated_on"
    t.index ["user_id"], name: "index_skate_sessions_on_user_id"
  end

  create_table "streak_justifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "reason", null: false
    t.datetime "reviewed_at"
    t.integer "reviewer_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["reviewer_id"], name: "index_streak_justifications_on_reviewer_id"
    t.index ["user_id"], name: "index_streak_justifications_on_user_id"
  end

  create_table "support_requests", force: :cascade do |t|
    t.string "contact"
    t.datetime "created_at", null: false
    t.datetime "handled_at"
    t.integer "kind", null: false
    t.integer "maneuver_id"
    t.text "message"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["maneuver_id"], name: "index_support_requests_on_maneuver_id"
    t.index ["user_id"], name: "index_support_requests_on_user_id"
  end

  create_table "training_sessions", force: :cascade do |t|
    t.datetime "clip_uploaded_at"
    t.datetime "created_at", null: false
    t.boolean "gear_checked", default: false, null: false
    t.boolean "ground_clear", default: false, null: false
    t.string "location_name"
    t.integer "maneuver_id", null: false
    t.integer "mentor_id"
    t.text "notes"
    t.integer "outcome"
    t.integer "period"
    t.boolean "queued_offline", default: false, null: false
    t.boolean "recorded_at_meetup", default: false, null: false
    t.date "scheduled_on"
    t.boolean "space_safe", default: false, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["clip_uploaded_at"], name: "index_training_sessions_on_clip_uploaded_at"
    t.index ["maneuver_id"], name: "index_training_sessions_on_maneuver_id"
    t.index ["mentor_id"], name: "index_training_sessions_on_mentor_id"
    t.index ["scheduled_on"], name: "index_training_sessions_on_scheduled_on"
    t.index ["user_id", "status"], name: "index_training_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_training_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.json "avatar_options", default: {}, null: false
    t.integer "birth_year"
    t.json "board_options", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "google_uid"
    t.datetime "last_seen_at"
    t.datetime "mentor_approved_at"
    t.integer "mentor_approved_by_id"
    t.text "mentor_bio"
    t.text "mentor_request_note"
    t.datetime "mentor_requested_at"
    t.string "nickname"
    t.string "nickname_key"
    t.string "nickname_tag"
    t.string "password_digest"
    t.string "phone"
    t.datetime "registered_at"
    t.integer "role", default: 0, null: false
    t.datetime "terms_accepted_at"
    t.string "time_zone", default: "America/Sao_Paulo", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "email IS NOT NULL"
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true, where: "google_uid IS NOT NULL"
    t.index ["mentor_approved_by_id"], name: "index_users_on_mentor_approved_by_id"
    t.index ["nickname_key", "nickname_tag"], name: "index_users_on_nickname_key_and_nickname_tag", unique: true, where: "nickname_key IS NOT NULL"
    t.index ["phone"], name: "index_users_on_phone", unique: true, where: "phone IS NOT NULL"
    t.index ["token"], name: "index_users_on_token", unique: true
  end

  add_foreign_key "access_codes", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_reviews", "training_sessions"
  add_foreign_key "ai_reviews", "users", column: "reviewer_id"
  add_foreign_key "clip_accesses", "training_sessions", on_delete: :cascade
  add_foreign_key "clip_accesses", "users", column: "viewer_id", on_delete: :nullify
  add_foreign_key "comebacks", "users"
  add_foreign_key "conversations", "users", column: "learner_id"
  add_foreign_key "diagnoses", "users"
  add_foreign_key "diagnosis_blockers", "diagnoses"
  add_foreign_key "instruction_steps", "maneuvers"
  add_foreign_key "maneuver_progresses", "maneuvers"
  add_foreign_key "maneuver_progresses", "users"
  add_foreign_key "maneuvers", "learning_modules"
  add_foreign_key "maneuvers", "maneuvers", column: "prerequisite_id"
  add_foreign_key "meetups", "users", on_delete: :cascade
  add_foreign_key "mentor_notes", "users", column: "author_id", on_delete: :nullify
  add_foreign_key "mentor_notes", "users", column: "learner_id", on_delete: :cascade
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "author_id", on_delete: :nullify
  add_foreign_key "skate_sessions", "training_sessions", on_delete: :nullify
  add_foreign_key "skate_sessions", "users", on_delete: :cascade
  add_foreign_key "streak_justifications", "users", column: "reviewer_id", on_delete: :nullify
  add_foreign_key "streak_justifications", "users", on_delete: :cascade
  add_foreign_key "support_requests", "maneuvers"
  add_foreign_key "support_requests", "users"
  add_foreign_key "training_sessions", "maneuvers"
  add_foreign_key "training_sessions", "users"
  add_foreign_key "training_sessions", "users", column: "mentor_id", on_delete: :nullify
  add_foreign_key "users", "users", column: "mentor_approved_by_id"
end
