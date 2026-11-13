FactoryBot.define do
  factory :part do
    datasheet
    part_reference { "RM-152" }
    phrase { "DM-152 NISSAN PICKUP" }
    fingerprint { "#{part_reference} #{phrase}".upcase.squish }
    brand { "Rexite" }
    item_group { "BOMBA DE ACEITE" }
  end
end
