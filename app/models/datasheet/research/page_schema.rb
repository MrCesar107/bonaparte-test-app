class Datasheet::Research::PageSchema < Schematist::Schema
  string :part_number
  string :subsystem
  string :product
  string :description

  array :applications do
    object do
      string :manufacturer
      string :model
      string :submodel
      string :start_year
      string :end_year
      string :liters
      string :engine_cc
      string :engine_cid
      string :engine_cylinders
      string :block
      string :fuel_type
      string :market
    end
  end

  array :interchanges do
    object do
      string :number
      string :brand
    end
  end

  array :attributes do
    object do
      string :attribute_class
      string :name
      string :unit
      string :value
    end
  end
end
