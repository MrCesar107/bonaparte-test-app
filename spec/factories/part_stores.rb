FactoryBot.define do
  factory :part_store do
    sequence(:name) { |n| "Part Store #{n}" }
  end
end
