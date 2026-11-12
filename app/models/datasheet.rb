class Datasheet < ApplicationRecord
  belongs_to :part_store

  enum status: {
    "created" => "created",
    "not_found" => "not_found",
    "failed" => "failed"
  }

  validates :equivalent, presence: true, uniqueness: { scope: :part_store_id }
  validates :url, presence: true
  validates :status, presence: true
end
