class AssociateSourceRowsWithDatasheets < ActiveRecord::Migration[8.1]
  def change
    remove_reference :source_rows, :part_store, foreign_key: true, index: true
    add_reference :source_rows, :datasheet, null: false, foreign_key: true, index: true
  end
end
