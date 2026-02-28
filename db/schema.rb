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

ActiveRecord::Schema[8.1].define(version: 2026_02_28_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "organizations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "plan_id"
    t.string "stripe_customer_id"
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["plan_id"], name: "index_organizations_on_plan_id"
    t.index ["subdomain"], name: "index_organizations_on_subdomain", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "price_cents"
    t.integer "room_limit"
    t.string "stripe_price_id"
    t.datetime "updated_at", null: false
  end

  create_table "reservations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.time "end_time"
    t.bigint "organization_id", null: false
    t.string "organizer"
    t.string "password_digest"
    t.string "purpose"
    t.bigint "room_id", null: false
    t.time "start_time"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_reservations_on_organization_id"
    t.index ["room_id", "date"], name: "index_reservations_on_room_id_and_date"
    t.index ["room_id"], name: "index_reservations_on_room_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.string "floor"
    t.string "name"
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "floor"], name: "index_rooms_on_organization_id_and_floor"
    t.index ["organization_id"], name: "index_rooms_on_organization_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.bigint "organization_id", null: false
    t.bigint "plan_id", null: false
    t.string "status"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id", unique: true
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true, where: "(stripe_subscription_id IS NOT NULL)"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.bigint "organization_id", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "reservations", "organizations"
  add_foreign_key "reservations", "rooms"
  add_foreign_key "rooms", "organizations"
  add_foreign_key "subscriptions", "organizations"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "users", "organizations"
end
