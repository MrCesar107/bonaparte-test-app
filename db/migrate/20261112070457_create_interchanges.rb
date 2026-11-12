class CreateInterchanges < ActiveRecord::Migration[8.1]
  def change
    create_table :interchanges do |t|
      t.belongs_to :datasheet, null: false, foreign_key: true, index: true
      t.integer :sort_order, null: false, default: 0
      t.string :number
      t.string :brand
      t.string :origin

      t.timestamps
    end
  end
end
