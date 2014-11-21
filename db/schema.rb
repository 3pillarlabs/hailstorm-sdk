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

ActiveRecord::Schema.define(version: 20141120091905) do

  create_table "clusters", force: true do |t|
    t.integer  "project_id",                                         null: false
    t.string   "name",                      default: "amazon_cloud", null: false
    t.string   "access_key",                                         null: false
    t.string   "secret_key",                                         null: false
    t.string   "region",                                             null: false
    t.string   "instance_type",                                      null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ssh_identity_file_name"
    t.string   "ssh_identity_content_type"
    t.integer  "ssh_identity_file_size"
    t.datetime "ssh_identity_updated_at"
  end

  add_index "clusters", ["project_id"], name: "index_clusters_on_project_id", using: :btree

	create_table "test_plans", force: true do |t|
    t.integer  "project_id"
    t.boolean  "status",     default: false, null: false
    t.text     "properties"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "projects", force: true do |t|
    t.string   "title",                      null: false
    t.boolean  "status",     default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
