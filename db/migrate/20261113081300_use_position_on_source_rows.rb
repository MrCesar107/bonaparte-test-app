class UsePositionOnSourceRows < ActiveRecord::Migration[8.1]
  def change
    remove_index :source_rows, :datasheet_id
    rename_column :source_rows, :sort_order, :position
    change_column_default :source_rows, :position, from: 0, to: nil
    add_index :source_rows, [ :datasheet_id, :position ], unique: true
  end
end
