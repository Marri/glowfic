# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_06_28_043840) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "audits", id: :serial, force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.datetime "created_at"
    t.string "request_uuid"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id"], name: "auditable_index"
  end

  create_table "blocks", force: :cascade do |t|
    t.integer "blocking_user_id", null: false
    t.integer "blocked_user_id", null: false
    t.boolean "block_interactions", default: true
    t.integer "hide_them", default: 0
    t.integer "hide_me", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_user_id"], name: "index_blocks_on_blocked_user_id"
    t.index ["blocking_user_id"], name: "index_blocks_on_blocking_user_id"
  end

  create_table "board_authors", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "board_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "cameo", default: false
    t.index ["board_id"], name: "index_board_authors_on_board_id"
    t.index ["user_id"], name: "index_board_authors_on_user_id"
  end

  create_table "board_sections", id: :serial, force: :cascade do |t|
    t.integer "board_id", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.integer "section_order", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
  end

  create_table "board_views", id: :serial, force: :cascade do |t|
    t.integer "board_id", null: false
    t.integer "user_id", null: false
    t.boolean "ignored", default: false
    t.boolean "notify_message", default: false
    t.boolean "notify_email", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "read_at"
    t.index ["user_id", "board_id"], name: "index_board_views_on_user_id_and_board_id", unique: true
  end

  create_table "boards", id: :serial, force: :cascade do |t|
    t.citext "name", null: false
    t.integer "creator_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
    t.boolean "pinned", default: false
    t.boolean "authors_locked", default: true
  end

  create_table "character_aliases", id: :serial, force: :cascade do |t|
    t.integer "character_id", null: false
    t.string "name", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["character_id"], name: "index_character_aliases_on_character_id"
  end

  create_table "character_groups", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
  end

  create_table "character_tags", id: :serial, force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["character_id"], name: "index_character_tags_on_character_id"
    t.index ["tag_id"], name: "index_character_tags_on_tag_id"
  end

  create_table "characters", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.citext "name", null: false
    t.string "nickname"
    t.string "screenname"
    t.integer "template_id"
    t.integer "default_icon_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "pb"
    t.integer "character_group_id"
    t.text "description"
    t.boolean "retired", default: false
    t.string "cluster"
    t.index ["character_group_id"], name: "index_characters_on_character_group_id"
    t.index ["template_id"], name: "index_characters_on_template_id"
    t.index ["user_id"], name: "index_characters_on_user_id"
  end

  create_table "characters_galleries", id: :serial, force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "gallery_id", null: false
    t.integer "section_order", default: 0, null: false
    t.boolean "added_by_group", default: false
    t.index ["character_id"], name: "index_characters_galleries_on_character_id"
    t.index ["gallery_id"], name: "index_characters_galleries_on_gallery_id"
  end

  create_table "favorites", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "favorite_id", null: false
    t.string "favorite_type", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["favorite_id", "favorite_type"], name: "index_favorites_on_favorite_id_and_favorite_type"
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "flat_posts", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.text "content"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["post_id"], name: "index_flat_posts_on_post_id"
  end

  create_table "galleries", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id"], name: "index_galleries_on_user_id"
  end

  create_table "galleries_icons", id: :serial, force: :cascade do |t|
    t.integer "icon_id"
    t.integer "gallery_id"
    t.index ["gallery_id"], name: "index_galleries_icons_on_gallery_id"
    t.index ["icon_id"], name: "index_galleries_icons_on_icon_id"
  end

  create_table "gallery_tags", id: :serial, force: :cascade do |t|
    t.integer "gallery_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["gallery_id"], name: "index_gallery_tags_on_gallery_id"
    t.index ["tag_id"], name: "index_gallery_tags_on_tag_id"
  end

  create_table "icons", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "url", null: false
    t.string "keyword", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "credit"
    t.boolean "has_gallery", default: false
    t.string "s3_key"
    t.index ["has_gallery"], name: "index_icons_on_has_gallery"
    t.index ["keyword"], name: "index_icons_on_keyword"
    t.index ["url"], name: "index_icons_on_url"
    t.index ["user_id"], name: "index_icons_on_user_id"
  end

  create_table "index_posts", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "index_id", null: false
    t.integer "index_section_id"
    t.text "description"
    t.integer "section_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["index_id"], name: "index_index_posts_on_index_id"
    t.index ["post_id"], name: "index_index_posts_on_post_id"
  end

  create_table "index_sections", id: :serial, force: :cascade do |t|
    t.integer "index_id", null: false
    t.citext "name", null: false
    t.text "description"
    t.integer "section_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["index_id"], name: "index_index_sections_on_index_id"
  end

  create_table "indexes", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.citext "name", null: false
    t.text "description"
    t.integer "privacy", default: 0, null: false
    t.boolean "authors_locked", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_indexes_on_user_id"
  end

  create_table "messages", id: :serial, force: :cascade do |t|
    t.integer "sender_id", null: false
    t.integer "recipient_id", null: false
    t.integer "parent_id"
    t.integer "thread_id"
    t.string "subject"
    t.text "message"
    t.boolean "unread", default: true
    t.boolean "visible_inbox", default: true
    t.boolean "visible_outbox", default: true
    t.boolean "marked_inbox", default: false
    t.boolean "marked_outbox", default: false
    t.datetime "read_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["recipient_id", "unread"], name: "index_messages_on_recipient_id_and_unread"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
    t.index ["thread_id"], name: "index_messages_on_thread_id"
  end

  create_table "news", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "news_views", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "news_id"
    t.index ["user_id"], name: "index_news_views_on_user_id"
  end

  create_table "password_resets", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "auth_token", null: false
    t.boolean "used", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["auth_token"], name: "index_password_resets_on_auth_token", unique: true
    t.index ["user_id", "created_at"], name: "index_password_resets_on_user_id_and_created_at"
  end

  create_table "post_authors", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "post_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "can_owe", default: true
    t.boolean "can_reply", default: true
    t.boolean "joined", default: false
    t.datetime "joined_at"
    t.text "private_note"
    t.index ["post_id"], name: "index_post_authors_on_post_id"
    t.index ["user_id"], name: "index_post_authors_on_user_id"
  end

  create_table "post_tags", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "tag_id", null: false
    t.boolean "suggested", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["post_id"], name: "index_post_tags_on_post_id"
    t.index ["tag_id"], name: "index_post_tags_on_tag_id"
  end

  create_table "post_viewers", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["post_id"], name: "index_post_viewers_on_post_id"
  end

  create_table "post_views", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "user_id", null: false
    t.boolean "ignored", default: false
    t.boolean "notify_message", default: false
    t.boolean "notify_email", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "read_at"
    t.boolean "warnings_hidden", default: false
    t.index ["user_id", "post_id"], name: "index_post_views_on_user_id_and_post_id", unique: true
  end

  create_table "posts", id: :serial, force: :cascade do |t|
    t.integer "board_id", null: false
    t.integer "user_id", null: false
    t.string "subject", null: false
    t.text "content"
    t.integer "character_id"
    t.integer "icon_id"
    t.integer "privacy", default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "status", default: 0
    t.integer "section_id"
    t.integer "section_order"
    t.string "description"
    t.integer "last_user_id"
    t.integer "last_reply_id"
    t.datetime "edited_at"
    t.datetime "tagged_at"
    t.boolean "authors_locked", default: false
    t.integer "character_alias_id"
    t.index "to_tsvector('english'::regconfig, COALESCE((subject)::text, ''::text))", name: "idx_fts_post_subject", using: :gin
    t.index "to_tsvector('english'::regconfig, COALESCE(content, ''::text))", name: "idx_fts_post_content", using: :gin
    t.index ["board_id"], name: "index_posts_on_board_id"
    t.index ["character_id"], name: "index_posts_on_character_id"
    t.index ["created_at"], name: "index_posts_on_created_at"
    t.index ["icon_id"], name: "index_posts_on_icon_id"
    t.index ["tagged_at"], name: "index_posts_on_tagged_at"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "replies", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "user_id", null: false
    t.text "content"
    t.integer "character_id"
    t.integer "icon_id"
    t.integer "thread_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "character_alias_id"
    t.integer "reply_order"
    t.index "to_tsvector('english'::regconfig, COALESCE(content, ''::text))", name: "idx_fts_reply_content", using: :gin
    t.index ["character_id"], name: "index_replies_on_character_id"
    t.index ["created_at"], name: "index_replies_on_created_at"
    t.index ["icon_id"], name: "index_replies_on_icon_id"
    t.index ["post_id", "reply_order"], name: "index_replies_on_post_id_and_reply_order"
    t.index ["post_id"], name: "index_replies_on_post_id"
    t.index ["thread_id"], name: "index_replies_on_thread_id"
    t.index ["user_id"], name: "index_replies_on_user_id"
  end

  create_table "reply_drafts", id: :serial, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "user_id", null: false
    t.text "content"
    t.integer "character_id"
    t.integer "icon_id"
    t.integer "thread_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "character_alias_id"
    t.index ["post_id", "user_id"], name: "index_reply_drafts_on_post_id_and_user_id"
  end

  create_table "report_views", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "read_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id"], name: "index_report_views_on_user_id"
  end

  create_table "tag_tags", id: :serial, force: :cascade do |t|
    t.integer "tagged_id", null: false
    t.integer "tag_id", null: false
    t.boolean "suggested", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["tag_id"], name: "index_tag_tags_on_tag_id"
    t.index ["tagged_id"], name: "index_tag_tags_on_tagged_id"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.citext "name", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "type"
    t.text "description"
    t.boolean "owned", default: false
    t.index ["name"], name: "index_tags_on_name"
    t.index ["type"], name: "index_tags_on_type"
  end

  create_table "templates", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.citext "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
    t.index ["user_id"], name: "index_templates_on_user_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.citext "username", null: false
    t.string "crypted", null: false
    t.integer "avatar_id"
    t.integer "active_character_id"
    t.integer "per_page", default: 25
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "timezone"
    t.citext "email"
    t.boolean "email_notifications"
    t.boolean "icon_picker_grouping", default: true
    t.string "moiety"
    t.string "layout"
    t.string "moiety_name"
    t.string "default_view"
    t.string "default_editor", default: "rtf"
    t.string "time_display", default: "%b %d, %Y %l:%M %p"
    t.string "salt_uuid"
    t.boolean "unread_opened", default: false
    t.boolean "hide_hiatused_tags_owed", default: false
    t.boolean "hide_warnings", default: false
    t.boolean "visible_unread", default: false
    t.boolean "show_user_in_switcher", default: true
    t.boolean "ignore_unread_daily_report", default: false
    t.boolean "favorite_notifications", default: true
    t.string "default_character_split", default: "template"
    t.integer "role_id"
    t.integer "tos_version"
    t.boolean "deleted", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

end
