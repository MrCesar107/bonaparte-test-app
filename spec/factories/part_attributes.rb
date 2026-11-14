FactoryBot.define do
  factory :part_attribute, class: "Attribute" do
    datasheet
    sequence(:sort_order)
    attribute_class { "Altura" }
    name { "Altura" }
    unit { "mm" }
    value { "10" }
  end
end
