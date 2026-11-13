class Datasheet < ApplicationRecord
  belongs_to :part_store

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
