# An interchange is an alternative part number, its brand, and its OEM or aftermarket origin.
# It is associated with a datasheet and has a number, brand, and origin.
class Interchange < ApplicationRecord
  belongs_to :datasheet
end
