FactoryBot.define do
  factory :interchange do
    datasheet
    sequence(:sort_order)
    number { "DM-152" }
    brand { "Melling" }
    origin { "Aftermarket" }
  end
end
