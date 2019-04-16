class InitMigration < ActiveRecord::Migration[5.2]
  def change
    create_table :categories do |c|
        c.text :category_name
      end
    
      create_table :products do |pr|
        pr.belongs_to :category, index: true
        pr.text :name
        pr.text :description
        pr.text :image_id
      end
    
      create_table :users do |u|
        u.text :usid
        u.string :used_keyboards_array
        u.string :user_basket_array
        u.string :user_final_basket
      end
      
      create_table :orders do |o|
        o.belongs_to :user, index: true
        o.text :entered_name
        o.text :entered_phone
        o.text :entered_adress
        o.string :user_complete_order
      end
    end
end