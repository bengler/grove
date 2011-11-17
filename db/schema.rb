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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110926230557) do

  create_table "posts", :force => true do |t|
    t.text     "document"
    t.text     "realm"
    t.text     "box"
    t.text     "collection"
    t.tsvector "tags_vector"
    t.integer  "created_by"
    t.datetime "synced_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "posts", ["box"], :name => "index_posts_on_box"
  add_index "posts", ["collection"], :name => "index_posts_on_collection"
  add_index "posts", ["created_at"], :name => "index_posts_on_created_at"
  add_index "posts", ["created_by"], :name => "index_posts_on_created_by"
  add_index "posts", ["realm"], :name => "index_posts_on_realm"
  add_index "posts", ["updated_at"], :name => "index_posts_on_updated_at"

end
