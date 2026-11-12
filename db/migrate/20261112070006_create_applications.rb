class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications do |t|
      t.belongs_to :datasheet, null: false, foreign_key: true, index: true
      t.integer :sort_order, null: false, default: 0
      t.string :manufacturer
      t.string :model
      t.string :submodel
      t.string :start_year
      t.string :end_year
      t.string :liters
      t.string :engine_cc
      t.string :engine_cid
      t.string :engine_cylinders
      t.string :block
      t.string :fuel_type
      t.string :market
      t.string :position

      t.timestamps
    end
  end
end
