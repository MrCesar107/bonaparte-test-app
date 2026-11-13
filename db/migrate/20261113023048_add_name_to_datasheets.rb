class AddNameToDatasheets < ActiveRecord::Migration[8.1]
  def change
    add_column :datasheets, :name, :string, null: false
  end
end
