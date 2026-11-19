# Represents an uploaded catalog or a researched equivalent part within a store.
# An upload holds the original spreadsheet rows; an equivalent's datasheet holds
# the researched fitments, interchanges, and specifications shared by several parts.

# Its status tracks processing or research outcomes, and only created research
# contributes details to the published catalog.
class Datasheet < ApplicationRecord
  belongs_to :part_store

  has_many :source_rows, -> { order(:position) }, dependent: :destroy
  has_many :parts, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :interchanges, dependent: :destroy
  has_many :part_attributes, class_name: "Attribute", dependent: :destroy

  has_one_attached :file

  enum :status, {
    pending: "pending",
    created: "created",
    not_found: "not_found",
    failed: "failed"
  }

  after_create_commit :generate_name

  private

  def generate_name
    update(name: "datasheet_#{created_at.strftime("%Y%m%d%H%M%S")}")
  end
end
