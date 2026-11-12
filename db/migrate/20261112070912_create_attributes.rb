class CreateAttributes < ActiveRecord::Migration[8.1]
  def change
    create_table :attributes do |t|
      t.belongs_to :datasheet, null: false, foreign_key: true, index: true
      t.integer :sort_order, null: false, default: 0
      t.string :attribute_class
      t.string :name
      t.string :unit
      t.string :value

      t.timestamps
    end
  end
end
