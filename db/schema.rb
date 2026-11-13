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

ActiveRecord::Schema[8.1].define(version: 2026_11_13_023129) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "applications", force: :cascade do |t|
    t.bigint "datasheet_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "manufacturer"
    t.string "model"
    t.string "submodel"
    t.string "start_year"
    t.string "end_year"
    t.string "liters"
    t.string "engine_cc"
    t.string "engine_cid"
    t.string "engine_cylinders"
    t.string "block"
    t.string "fuel_type"
    t.string "market"
    t.string "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["datasheet_id"], name: "index_applications_on_datasheet_id"
  end

  create_table "attributes", force: :cascade do |t|
    t.bigint "datasheet_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "attribute_class"
    t.string "name"
    t.string "unit"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["datasheet_id"], name: "index_attributes_on_datasheet_id"
  end

  create_table "datasheets", force: :cascade do |t|
    t.bigint "part_store_id", null: false
    t.string "equivalent"
    t.string "url"
    t.string "status", default: "pending"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.index ["part_store_id", "equivalent"], name: "index_datasheets_on_part_store_id_and_equivalent", unique: true
    t.index ["part_store_id"], name: "index_datasheets_on_part_store_id"
  end

  create_table "interchanges", force: :cascade do |t|
    t.bigint "datasheet_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "number"
    t.string "brand"
    t.string "origin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["datasheet_id"], name: "index_interchanges_on_datasheet_id"
  end

  create_table "part_stores", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "parts", force: :cascade do |t|
    t.bigint "datasheet_id", null: false
    t.string "part_reference"
    t.string "phrase"
    t.string "fingerprint"
    t.string "brand"
    t.string "item_group"
    t.string "category"
    t.string "vehicle_system"
    t.string "subsystem"
    t.string "product"
    t.string "description"
    t.string "unconfirmed_tokens", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["datasheet_id"], name: "index_parts_on_datasheet_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applications", "datasheets"
  add_foreign_key "attributes", "datasheets"
  add_foreign_key "datasheets", "part_stores"
  add_foreign_key "interchanges", "datasheets"
  add_foreign_key "parts", "datasheets"
end
