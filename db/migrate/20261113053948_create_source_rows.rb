class CreateSourceRows < ActiveRecord::Migration[8.1]
  def change
    create_table :source_rows do |t|
      t.belongs_to :part_store, null: false, foreign_key: true, index: true
      t.integer :sort_order, null: false, default: 0
      t.string :internal_code
      t.string :part_number
      t.string :description
      t.string :article_description
      t.string :item_group
      t.string :manufacturer
      t.string :unit

      t.timestamps
    end
  end
end
