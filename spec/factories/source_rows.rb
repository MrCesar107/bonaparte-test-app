FactoryBot.define do
  factory :source_row do
    datasheet
    sequence(:position)
    internal_code { "RM-152" }
    part_number { "DM-152" }
    description { "Nissan Tsuru 16v 1992-2017" }
    article_description { "BOMBA DE ACEITE" }
    item_group { "BOMBAS" }
    manufacturer { "Rexite" }
    unit { "PZA" }
  end
end
