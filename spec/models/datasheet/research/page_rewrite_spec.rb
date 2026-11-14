require "rails_helper"
require "ruby_llm/test_helper"

RSpec.describe Datasheet::Research::PageRewrite do
  include RubyLLM::TestHelper

  describe "#call" do
    it "turns the model's JSON into lists and marks vehicle brands as OEM" do
      stub_replies page_json

      lists = described_class.new.call("<p>Melling M152 oil pump</p>")

      expect(lists.part_number).to eq("M152")
      expect(lists.subsystem).to eq("Pumps")
      expect(lists.product).to eq("Oil pump")
      expect(lists.description).to eq("Fits Nissan trucks")
      expect(lists.applications.first).to have_attributes(
        manufacturer: "Nissan",
        model: "D21",
        start_year: "1986",
        end_year: "1994",
        engine_cc: "2389"
      )
      expect(lists.interchanges.map(&:origin)).to eq([ "Aftermarket", "OEM" ])
      expect(lists.attributes.first).to have_attributes(name: "Height", unit: "mm", value: "10")
      expect(lists.unconfirmed_tokens).to eq([])
    end

    it "raises unavailable when the model does not respond" do
      stub_replies RubyLLM::ServerError.new("The provider is down")

      expect { described_class.new.call("<p>page</p>") }.to raise_error(Datasheet::Research::Unavailable)
    end
  end

  def page_json
    {
      part_number: "M152",
      subsystem: "Pumps",
      product: "Oil pump",
      description: "Fits Nissan trucks",
      applications: [
        {
          manufacturer: "Nissan",
          model: "D21",
          submodel: "",
          start_year: "1986",
          end_year: "1994",
          liters: "2.4",
          engine_cc: "2389",
          engine_cid: "",
          engine_cylinders: "4",
          block: "L",
          fuel_type: "Gasoline",
          market: "MEX"
        }
      ],
      interchanges: [
        { number: "DM-152", brand: "Melling" },
        { number: "15010-40F00", brand: "Nissan" }
      ],
      attributes: [
        { attribute_class: "Height", name: "Height", unit: "mm", value: "10" }
      ]
    }.to_json
  end
end
