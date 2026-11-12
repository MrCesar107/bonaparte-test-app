class CreateParts < ActiveRecord::Migration[8.1]
  def change
    create_table :parts do |t|
      t.belongs_to :datasheet, null: false, foreign_key: true, index: true
      t.string :part_reference
      t.string :phrase
      t.string :fingerprint
      t.string :brand
      t.string :item_group
      t.string :category
      t.string :system
      t.string :subsystem
      t.string :product
      t.string :description
      t.string :unconfirmed_tokens, array: true

      t.timestamps
    end
  end
end
