class CreatePartStores < ActiveRecord::Migration[8.1]
  def change
    create_table :part_stores do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
