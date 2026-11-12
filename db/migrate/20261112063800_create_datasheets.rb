class CreateDatasheets < ActiveRecord::Migration[8.1]
  def change
    create_table :datasheets do |t|
      t.belongs_to :part_store, null: false, foreign_key: true
      t.string :equivalent, null: false
      t.index [ :part_store_id, :equivalent ], unique: true
      t.string :url, null: false
      t.string :status, null: false

      t.timestamps
    end
  end
end
