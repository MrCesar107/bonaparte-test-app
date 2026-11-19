# An application is a vehicle fitment for a specific part. It includes
# the year range and engine details.
#
# For example, a part that fits a 2010-2015 Toyota Camry with a 2.5L engine would be
# an application for the Toyota Camry 2.5L.
class Application < ApplicationRecord
  belongs_to :datasheet
end
