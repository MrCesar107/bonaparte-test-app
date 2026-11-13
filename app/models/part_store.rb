class PartStore < ApplicationRecord
  validates :name, presence: true

  has_many :datasheets, dependent: :destroy
end
