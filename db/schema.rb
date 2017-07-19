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

ActiveRecord::Schema.define(version: 20150530184832) do

  create_table "clusters", force: true do |t|
    t.integer  "project_id",                null: false
    t.string   "access_key"
    t.string   "secret_key"
    t.string   "region"
    t.string   "instance_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ssh_identity_file_name"
    t.string   "ssh_identity_content_type"
    t.integer  "ssh_identity_file_size"
    t.datetime "ssh_identity_updated_at"
    t.string   "user_name"
    t.text     "machines"
    t.string   "type"
    t.string   "title"
    t.integer  "max_threads_per_agent"
  end

  add_index "clusters", ["project_id"], name: "index_clusters_on_project_id", using: :btree

  create_table "load_tests", force: true do |t|
    t.integer  "execution_cycle_id"
    t.integer  "project_id"
    t.integer  "total_threads_count"
    t.float    "avg_90_percentile",   limit: 24
    t.float    "avg_tps",             limit: 24
    t.datetime "started_at"
    t.datetime "stopped_at"
    t.boolean  "active",                         default: true
  end

  create_table "project_result_downloads", force: true do |t|
    t.string   "test_ids"
    t.integer  "project_id"
    t.integer  "status",      default: 0, null: false
    t.string   "result_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "projects", force: true do |t|
    t.string   "title",                    null: false
    t.integer  "status",       default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "aasm_state"
    t.string   "state_reason"
    t.string   "project_key"
  end

  create_table "target_hosts", force: true do |t|
    t.integer  "project_id",                                   null: false
    t.string   "host_name"
    t.string   "target_host_type",          default: "nmon",   null: false
    t.string   "role_name"
    t.string   "executable_path"
    t.string   "user_name",                 default: "ubuntu"
    t.integer  "sampling_interval",         default: 10,       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ssh_identity_file_name"
    t.string   "ssh_identity_content_type"
    t.integer  "ssh_identity_file_size"
    t.datetime "ssh_identity_updated_at"
  end

  add_index "target_hosts", ["project_id"], name: "index_target_hosts_on_project_id", using: :btree

  create_table "test_plans", force: true do |t|
    t.integer  "project_id"
    t.boolean  "status",           default: false, null: false
    t.text     "properties"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "jmx_file_name"
    t.string   "jmx_content_type"
    t.integer  "jmx_file_size"
    t.datetime "jmx_updated_at"
  end

end
