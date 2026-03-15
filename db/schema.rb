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

ActiveRecord::Schema[8.1].define(version: 2025_01_01_000019) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "connected_integrations", force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.datetime "last_synced_at", precision: nil
    t.string "provider", null: false
    t.text "refresh_token"
    t.string "scopes"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "provider"], name: "index_connected_integrations_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_connected_integrations_on_user_id"
  end

  create_table "daily_control_flags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_control_id", null: false
    t.string "flag_type", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["daily_control_id", "flag_type"], name: "index_daily_control_flags_on_daily_control_id_and_flag_type"
    t.index ["daily_control_id"], name: "index_daily_control_flags_on_daily_control_id"
  end

  create_table "daily_controls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "exercise_intensity"
    t.text "notes"
    t.decimal "sleep_hours", precision: 4, scale: 1
    t.integer "sleep_quality"
    t.integer "stress_level"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "date"], name: "index_daily_controls_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_daily_controls_on_user_id"
  end

  create_table "food_category_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id", null: false
    t.bigint "food_sensitivity_category_id", null: false
    t.integer "severity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["food_id", "food_sensitivity_category_id"], name: "index_food_category_memberships_on_food_and_category", unique: true
    t.index ["food_id"], name: "index_food_category_memberships_on_food_id"
    t.index ["food_sensitivity_category_id"], name: "idx_on_food_sensitivity_category_id_e2ef5a1cc5"
  end

  create_table "food_sensitivity_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_food_sensitivity_categories_on_slug", unique: true
  end

  create_table "foods", force: :cascade do |t|
    t.string "barcode"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "open_food_facts_id"
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_foods_on_barcode"
    t.index ["open_food_facts_id"], name: "index_foods_on_open_food_facts_id"
  end

  create_table "hypothesis_suggestions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "reason_category_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "suggested_food_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["reason_category_id"], name: "index_hypothesis_suggestions_on_reason_category_id"
    t.index ["suggested_food_id"], name: "index_hypothesis_suggestions_on_suggested_food_id"
    t.index ["user_id", "status"], name: "index_hypothesis_suggestions_on_user_id_and_status"
    t.index ["user_id", "suggested_food_id", "reason_category_id"], name: "index_hypothesis_suggestions_unique", unique: true
    t.index ["user_id"], name: "index_hypothesis_suggestions_on_user_id"
  end

  create_table "ingredient_food_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id", null: false
    t.bigint "ingredient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_ingredient_food_mappings_on_food_id"
    t.index ["ingredient_id", "food_id"], name: "index_ingredient_food_mappings_on_ingredient_id_and_food_id", unique: true
    t.index ["ingredient_id"], name: "index_ingredient_food_mappings_on_ingredient_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.string "canonical_name", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_name"], name: "index_ingredients_on_canonical_name"
    t.index ["name"], name: "index_ingredients_on_name"
  end

  create_table "integration_sync_logs", force: :cascade do |t|
    t.bigint "connected_integration_id", null: false
    t.datetime "created_at", null: false
    t.integer "records_imported", default: 0
    t.string "status", null: false
    t.datetime "synced_at", precision: nil, null: false
    t.datetime "updated_at", null: false
    t.index ["connected_integration_id", "synced_at"], name: "idx_on_connected_integration_id_synced_at_1447fc604e"
    t.index ["connected_integration_id"], name: "index_integration_sync_logs_on_connected_integration_id"
  end

  create_table "meal_ingredients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_id"
    t.bigint "ingredient_id", null: false
    t.bigint "meal_id", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_meal_ingredients_on_food_id"
    t.index ["ingredient_id"], name: "index_meal_ingredients_on_ingredient_id"
    t.index ["meal_id", "ingredient_id"], name: "index_meal_ingredients_on_meal_id_and_ingredient_id"
    t.index ["meal_id"], name: "index_meal_ingredients_on_meal_id"
  end

  create_table "meal_plan_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "meal_id"
    t.bigint "meal_plan_id", null: false
    t.string "meal_time", null: false
    t.date "scheduled_for", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_id"], name: "index_meal_plan_slots_on_meal_id"
    t.index ["meal_plan_id", "scheduled_for", "meal_time"], name: "index_meal_plan_slots_on_plan_date_mealtime", unique: true
    t.index ["meal_plan_id"], name: "index_meal_plan_slots_on_meal_plan_id"
  end

  create_table "meal_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "starts_on"], name: "index_meal_plans_on_user_id_and_starts_on"
    t.index ["user_id"], name: "index_meal_plans_on_user_id"
  end

  create_table "meals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "eaten_at", precision: nil, null: false
    t.text "notes"
    t.boolean "planned", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "eaten_at"], name: "index_meals_on_user_id_and_eaten_at"
    t.index ["user_id"], name: "index_meals_on_user_id"
  end

  create_table "symptom_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "logged_at", precision: nil, null: false
    t.text "notes"
    t.integer "score", null: false
    t.bigint "symptom_type_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["symptom_type_id"], name: "index_symptom_logs_on_symptom_type_id"
    t.index ["user_id", "logged_at"], name: "index_symptom_logs_on_user_id_and_logged_at"
    t.index ["user_id"], name: "index_symptom_logs_on_user_id"
  end

  create_table "symptom_types", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_symptom_types_on_slug", unique: true
  end

  create_table "user_suspect_foods", force: :cascade do |t|
    t.datetime "added_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "food_id", null: false
    t.bigint "user_id", null: false
    t.index ["food_id"], name: "index_user_suspect_foods_on_food_id"
    t.index ["user_id", "food_id"], name: "index_user_suspect_foods_on_user_id_and_food_id", unique: true
    t.index ["user_id"], name: "index_user_suspect_foods_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "washout_windows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.bigint "food_sensitivity_category_id", null: false
    t.bigint "meal_plan_id", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["food_sensitivity_category_id"], name: "index_washout_windows_on_food_sensitivity_category_id"
    t.index ["meal_plan_id", "food_sensitivity_category_id", "start_date"], name: "index_washout_windows_on_plan_category_start"
    t.index ["meal_plan_id"], name: "index_washout_windows_on_meal_plan_id"
  end

  add_foreign_key "connected_integrations", "users"
  add_foreign_key "daily_control_flags", "daily_controls"
  add_foreign_key "daily_controls", "users"
  add_foreign_key "food_category_memberships", "food_sensitivity_categories"
  add_foreign_key "food_category_memberships", "foods"
  add_foreign_key "hypothesis_suggestions", "food_sensitivity_categories", column: "reason_category_id"
  add_foreign_key "hypothesis_suggestions", "foods", column: "suggested_food_id"
  add_foreign_key "hypothesis_suggestions", "users"
  add_foreign_key "ingredient_food_mappings", "foods"
  add_foreign_key "ingredient_food_mappings", "ingredients"
  add_foreign_key "integration_sync_logs", "connected_integrations"
  add_foreign_key "meal_ingredients", "foods"
  add_foreign_key "meal_ingredients", "ingredients"
  add_foreign_key "meal_ingredients", "meals"
  add_foreign_key "meal_plan_slots", "meal_plans"
  add_foreign_key "meal_plan_slots", "meals"
  add_foreign_key "meal_plans", "users"
  add_foreign_key "meals", "users"
  add_foreign_key "symptom_logs", "symptom_types"
  add_foreign_key "symptom_logs", "users"
  add_foreign_key "user_suspect_foods", "foods"
  add_foreign_key "user_suspect_foods", "users"
  add_foreign_key "washout_windows", "food_sensitivity_categories"
  add_foreign_key "washout_windows", "meal_plans"
end
