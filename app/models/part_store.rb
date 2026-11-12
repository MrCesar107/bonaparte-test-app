class PartStore < ApplicationRecord
  validates :name, presence: true

  has_many :datasheets, dependent: :restrict_with_error
end
