class EnforcePartFingerprintsPerStore < ActiveRecord::Migration[8.1]
  def up
    add_column :parts, :part_store_id, :bigint

    execute <<~SQL
      UPDATE parts
      SET part_store_id = datasheets.part_store_id
      FROM datasheets
      WHERE datasheets.id = parts.datasheet_id
    SQL

    if select_value(<<~SQL)
      SELECT 1
      FROM parts
      WHERE fingerprint IS NOT NULL
      GROUP BY part_store_id, fingerprint
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
      raise ActiveRecord::MigrationError, "Resolve duplicate part fingerprints within each store before adding the unique index."
    end

    change_column_null :parts, :part_store_id, false
    add_index :parts, [ :part_store_id, :fingerprint ], unique: true
    add_index :datasheets, [ :id, :part_store_id ], unique: true
    add_foreign_key :parts, :datasheets, column: [ :datasheet_id, :part_store_id ],
      primary_key: [ :id, :part_store_id ], on_update: :cascade, name: :fk_parts_datasheet_store
  end

  def down
    remove_foreign_key :parts, name: :fk_parts_datasheet_store
    remove_index :datasheets, [ :id, :part_store_id ]
    remove_column :parts, :part_store_id
  end
end
