FactoryBot.define do
  factory :application do
    datasheet
    sequence(:sort_order)
    manufacturer { "Nissan" }
    model { "D21" }
    submodel { "" }
    start_year { "1986" }
    end_year { "1988" }
    liters { "2.4" }
    engine_cc { "2389" }
    engine_cid { "" }
    engine_cylinders { "4" }
    block { "L" }
    fuel_type { "Gasolina" }
    market { "MEX" }
    position { "" }
  end
end
