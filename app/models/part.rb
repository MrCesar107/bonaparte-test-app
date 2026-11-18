class Part < ApplicationRecord
  belongs_to :datasheet

  before_save :copy_part_store_id, if: :will_save_change_to_datasheet_id?

  scope :for_part_store, ->(part_store_id) { where(part_store_id: part_store_id) }

  def self.insert_fingerprinted(rows, returning: false)
    insert_all(rows, unique_by: :index_parts_on_part_store_id_and_fingerprint, returning: returning)
  end

  private

  def copy_part_store_id
    self.part_store_id = datasheet.part_store_id
  end
end
