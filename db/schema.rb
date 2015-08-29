# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20150829185637) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "group_locations", force: true do |t|
    t.integer "group_id"
    t.integer "location_id"
  end

  add_index "group_locations", ["group_id", "location_id"], name: "index_group_locations_on_group_id_and_location_id", unique: true, using: :btree
  add_index "group_locations", ["group_id"], name: "index_group_locations_on_group_id", using: :btree
  add_index "group_locations", ["location_id"], name: "index_group_locations_on_location_id", using: :btree

  create_table "group_memberships", force: true do |t|
    t.integer  "group_id"
    t.integer  "identity_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "group_memberships", ["group_id", "identity_id"], name: "index_group_memberships_on_group_id_and_identity_id", unique: true, using: :btree
  add_index "group_memberships", ["group_id"], name: "index_group_memberships_on_group_id", using: :btree
  add_index "group_memberships", ["identity_id"], name: "index_group_memberships_on_identity_id", using: :btree

  create_table "locations", force: true do |t|
    t.text     "label_0"
    t.text     "label_1"
    t.text     "label_2"
    t.text     "label_3"
    t.text     "label_4"
    t.text     "label_5"
    t.text     "label_6"
    t.text     "label_7"
    t.text     "label_8"
    t.text     "label_9"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "locations", ["label_0", "label_1", "label_2", "label_3", "label_4", "label_5", "label_6", "label_7", "label_8", "label_9"], name: "index_locations_on_labels", unique: true, using: :btree

  create_table "locations_posts", id: false, force: true do |t|
    t.integer "location_id", null: false
    t.integer "post_id",     null: false
  end

  add_index "locations_posts", ["location_id", "post_id"], name: "index_locations_posts_on_location_id_and_post_id", unique: true, using: :btree
  add_index "locations_posts", ["location_id"], name: "index_locations_posts_on_location_id", using: :btree
  add_index "locations_posts", ["post_id"], name: "index_locations_posts_on_post_id", using: :btree

  create_table "occurrence_entries", force: true do |t|
    t.text     "label"
    t.integer  "post_id"
    t.datetime "at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "occurrence_entries", ["at"], name: "index_occurrence_entries_on_at", using: :btree
  add_index "occurrence_entries", ["post_id", "label"], name: "index_occurrence_entries_on_post_id_and_label", using: :btree

  create_table "posts", force: true do |t|
    t.text     "document"
    t.text     "realm"
    t.tsvector "tags_vector"
    t.integer  "created_by"
    t.boolean  "deleted",                      default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "external_id"
    t.text     "canonical_path"
    t.text     "klass"
    t.boolean  "restricted",                   default: false
    t.datetime "document_updated_at"
    t.datetime "external_document_updated_at"
    t.text     "external_document"
    t.boolean  "conflicted",                   default: false, null: false
    t.boolean  "published",                    default: true,  null: false
    t.text     "protected"
    t.text     "sensitive"
    t.integer  "version",                      default: 1,     null: false
  end

  add_index "posts", ["conflicted"], name: "index_posts_on_conflicted", using: :btree
  add_index "posts", ["created_at"], name: "index_posts_on_created_at", using: :btree
  add_index "posts", ["created_by"], name: "index_posts_on_created_by", using: :btree
  add_index "posts", ["deleted"], name: "index_posts_on_deleted", using: :btree
  add_index "posts", ["deleted"], name: "index_posts_on_deleted_where_not_deleted", where: "(NOT deleted)", using: :btree
  add_index "posts", ["klass"], name: "index_posts_on_klass", using: :btree
  add_index "posts", ["published"], name: "index_posts_on_published", using: :btree
  add_index "posts", ["realm", "external_id"], name: "index_posts_on_realm_and_external_id", unique: true, using: :btree
  add_index "posts", ["realm"], name: "index_posts_on_realm", using: :btree
  add_index "posts", ["restricted"], name: "index_posts_on_restricted", using: :btree
  add_index "posts", ["tags_vector"], name: "index_posts_on_tags_vector", using: :gist
  add_index "posts", ["updated_at"], name: "index_posts_on_updated_at", using: :btree

  create_table "readmarks", force: true do |t|
    t.integer  "location_id"
    t.integer  "post_id",      default: 0
    t.integer  "owner"
    t.integer  "unread_count", default: 0
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "readmarks", ["location_id"], name: "index_readmarks_on_location_id", using: :btree
  add_index "readmarks", ["owner"], name: "index_readmarks_on_owner", using: :btree

end
