class ChangeDatasheets < ActiveRecord::Migration[8.1]
  def change
    change_column_default :datasheets, :status, from: nil, to: "pending"
    change_column_null :datasheets, :equivalent, true
    change_column_null :datasheets, :url, true
    change_column_null :datasheets, :status, true
    change_column_null :datasheets, :name, true
    change_column_null :datasheets, :created_at, true
    change_column_null :datasheets, :updated_at, true
  end
end
