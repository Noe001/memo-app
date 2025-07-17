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

ActiveRecord::Schema[7.1].define(version: 2025_07_08_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "groups_tables", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "invited_by_id", null: false
    t.bigint "invited_user_id"
    t.string "email"
    t.string "token"
    t.integer "role"
    t.datetime "expires_at"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_invitations_on_group_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["invited_user_id"], name: "index_invitations_on_invited_user_id"
  end

  create_table "memo_tags", force: :cascade do |t|
    t.bigint "memo_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memo_id", "tag_id"], name: "index_memo_tags_on_memo_id_and_tag_id", unique: true
    t.index ["tag_id"], name: "index_memo_tags_on_tag_id"
  end

  create_table "memos", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "visibility", default: 0
    t.bigint "group_id"
    t.index ["group_id"], name: "index_memos_on_group_id"
    t.index ["user_id", "updated_at"], name: "index_memos_on_user_id_and_updated_at"
    t.index ["user_id", "visibility"], name: "index_memos_on_user_id_and_visibility"
    t.index ["visibility"], name: "index_memos_on_visibility"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id", "expires_at"], name: "index_sessions_on_user_id_and_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#007bff"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "user_groups", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_user_groups_on_group_id"
    t.index ["user_id"], name: "index_user_groups_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "theme", default: "light"
    t.boolean "keyboard_shortcuts_enabled", default: true
  end

  add_foreign_key "invitations", "groups"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "invitations", "users", column: "invited_user_id"
  add_foreign_key "memo_tags", "memos"
  add_foreign_key "memo_tags", "tags"
  add_foreign_key "memos", "groups"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_groups", "groups"
  add_foreign_key "user_groups", "users"
end
