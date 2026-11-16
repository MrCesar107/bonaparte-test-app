require "rails_helper"

RSpec.describe Datasheet::Research::Phrase do
  describe "#call" do
    it "cuts RM-152 before Nissan and builds the oil pump query" do
      phrase = cut(
        description: "DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14",
        part_number: "RM-152",
        item_group: "BOMBA DE ACEITE"
      )

      expect(phrase.candidates).to eq([ "DM-152", "RM-152" ])
      expect(phrase.oversize).to be_nil
      expect(phrase.years).to eq([ "1976", "2014" ])
      expect(phrase.group_alias).to eq("oil pump")
      expect(phrase.queries["DM-152"]).to eq(%("DM-152" Nissan oil pump 1976-2014))
    end

    it "expands short year pairs and keeps four digit years" do
      expect(cut(description: "00/50", part_number: "X").years).to eq([ "2000", "1950" ])
      expect(cut(description: "2014", part_number: "X").years).to eq([ "2014" ])
      expect(cut(description: "2014/2022", part_number: "X").years).to eq([ "2014", "2022" ])
    end

    it "matches the group alias without case or accents and keeps the longest key" do
      expect(cut(description: "X", part_number: "X", item_group: "PUNTERÍA HIDRÁULICA").group_alias).to eq("hydraulic lifter")
      expect(cut(description: "X", part_number: "X", item_group: "PUNTERIAS").group_alias).to eq("lifter")
      expect(cut(description: "X", part_number: "X", item_group: "KIT DE DISTRIBUCION").group_alias).to eq("timing chain kit")
      expect(cut(description: "X", part_number: "X", item_group: "JUEGO DE EMPAQUES").group_alias).to eq("full gasket set")
      expect(cut(description: "X", part_number: "X", item_group: "PISTON Y BOMBA DE ACEITE").group_alias).to eq("oil pump")
    end

    it "strips an oversize suffix and does not repeat the part number" do
      phrase = cut(
        description: "SP26-329R/L+20 CHEVROLET SILVERADO",
        part_number: "SP26-329R/L+20",
        item_group: "PISTON"
      )

      expect(phrase.candidates).to eq([ "SP26-329R/L" ])
      expect(phrase.oversize).to eq("+20")
    end

    it "starts with the part number when the phrase has no vehicle brand" do
      phrase = cut(description: "ELGIN 3.6 AFM", part_number: "HL-7025S", item_group: "PUNTERIA HIDRAULICA")

      expect(phrase.candidates).to eq([ "HL-7025S", "3.6" ])
    end

    it "does not cut on the part manufacturer" do
      phrase = cut(description: "REXITE NISSAN PICKUP", part_number: "RM-152")

      expect(phrase.candidates).to eq([ "REXITE", "RM-152" ])
    end

    it "cuts on Chrysler" do
      phrase = cut(description: "DM-152 CHRYSLER 300 2014", part_number: "RM-1")

      expect(phrase.candidates).to eq([ "DM-152", "RM-1" ])
    end
  end

  describe ".same_number?" do
    it "treats punctuation as the same writing" do
      expect(described_class.same_number?("9-0511S", "90511S")).to be(true)
    end

    it "accepts one extra prefix letter when the digits match and there are at least six" do
      expect(described_class.same_number?("FSX-5840301", "FS5840301")).to be(true)
      expect(described_class.same_number?("fsx-5840301", "FS5840301")).to be(true)
    end

    it "rejects one extra prefix letter on a short catalog code" do
      expect(described_class.same_number?("R-83-301", "83-301")).to be(false)
    end

    it "accepts a letter suffix when the base matches and there are at least five digits" do
      expect(described_class.same_number?("9-0511S", "9-0511SX")).to be(true)
      expect(described_class.same_number?("9-0511S", "9-0511SVVT")).to be(true)
    end

    it "rejects a different number, an equivalent and a short digit run" do
      expect(described_class.same_number?("SA-76260", "76260")).to be(false)
      expect(described_class.same_number?("DM-152", "M152")).to be(false)
      expect(described_class.same_number?("X152", "152")).to be(false)
      expect(described_class.same_number?("9-0511S", "9-0511S2")).to be(false)
    end
  end

  def cut(description:, part_number:, item_group: "BOMBA DE ACEITE")
    described_class.new(description: description, part_number: part_number, item_group: item_group).call
  end
end
