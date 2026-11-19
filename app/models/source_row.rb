# It represents one row from the uploaded Origen sheet.
# Is is used to store the original position, part number, and description from the input spreadsheet
# uploaded to build a datasheet.
class SourceRow < ApplicationRecord
  belongs_to :datasheet

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :datasheet_id }

  def fingerprint
    "#{part_number} #{description}".upcase.squish
  end
end
