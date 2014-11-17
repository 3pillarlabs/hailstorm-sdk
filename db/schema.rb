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

ActiveRecord::Schema.define(version: 20141117081900) do

  create_table "projects", force: true do |t|
    t.string   "title",                      null: false
    t.boolean  "status",     default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "projects", ["title"], name: "index_projects_on_title", unique: true, using: :btree

  create_table "test_plans", force: true do |t|
    t.integer  "project_id"
    t.boolean  "status",           default: false, null: false
    t.string   "default"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "jmx_file_name"
    t.string   "jmx_content_type"
    t.integer  "jmx_file_size"
    t.datetime "jmx_updated_at"
  end

end
