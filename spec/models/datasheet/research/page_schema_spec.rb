require "rails_helper"

RSpec.describe Datasheet::Research::PageSchema do
  it "requires the sheet fields and the three lists" do
    schema = described_class.new.to_json_schema
    required = Array(schema["required"] || schema[:required])
    properties = schema["properties"] || schema[:properties]

    expect(required).to include("part_number", "subsystem", "product", "description", "applications", "interchanges", "attributes")
    expect(properties.dig("applications", "items", "properties").keys).to include("start_year", "end_year", "engine_cc", "market")
    expect(properties.dig("interchanges", "items", "properties").keys).to include("number", "brand")
    expect(properties.dig("attributes", "items", "properties").keys).to include("attribute_class", "name", "unit", "value")
  end
end
