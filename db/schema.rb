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

ActiveRecord::Schema.define(version: 2019_04_04_111609) do

  create_table "categories", force: :cascade do |t|
    t.text "category_name"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "user_id"
    t.text "entered_name"
    t.text "entered_phone"
    t.text "entered_adress"
    t.string "user_complete_order"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.integer "category_id"
    t.text "name"
    t.text "description"
    t.text "image_id"
    t.index ["category_id"], name: "index_products_on_category_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "usid"
    t.string "used_keyboards_array"
    t.string "user_basket_array"
    t.string "user_final_basket"
  end

end
