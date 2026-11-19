# An attribute is a part specification, such as a dimension or material.
# It is associated with a datasheet and has a class, name, optional unit, and value.
class Attribute < ApplicationRecord
  belongs_to :datasheet
end
