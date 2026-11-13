require "rails_helper"

RSpec.describe Datasheet::Research::StoredRow do
  describe "#call" do
    it "reuses the first candidate that already has a datasheet" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      create(:datasheet, part_store: part_store, equivalent: "RM-152", status: :not_found, url: "")
      first = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :failed, url: "")
      source_row = create(
        :source_row,
        datasheet: upload,
        part_number: "RM-152",
        description: "DM-152 NISSAN PICKUP 76/14",
        item_group: "BOMBA DE ACEITE"
      )

      expect(described_class.new(part_store: part_store, source_row: source_row).call).to eq(:attached)
      expect(Part.find_by(part_reference: "RM-152").datasheet).to eq(first)
    end

    it "does not reuse a datasheet from another part store" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      create(:datasheet, equivalent: "DM-152", status: :created, url: "https://example.test")
      source_row = create(
        :source_row,
        datasheet: upload,
        part_number: "RM-152",
        description: "DM-152 NISSAN PICKUP 76/14"
      )

      expect(described_class.new(part_store: part_store, source_row: source_row).call).to eq(:missing)
      expect(Part.where(part_reference: "RM-152")).to be_empty
    end

    it "skips a row whose fingerprint is already stored" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://example.test")
      part = create_part(sheet, part_reference: "RM-152", phrase: "DM-152 NISSAN PICKUP", product: "Bomba de aceite")
      source_row = create(
        :source_row,
        datasheet: upload,
        part_number: "rm-152",
        description: "dm-152   nissan pickup"
      )

      expect(described_class.new(part_store: part_store, source_row: source_row).call).to eq(:skipped)
      expect(part.reload.product).to eq("Bomba de aceite")
      expect(Part.where(datasheet: sheet).count).to eq(1)
    end

    it "copies the commercial text when the datasheet exists and the fingerprint does not" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://example.test")
      create_part(
        sheet,
        part_reference: "OLD-1",
        phrase: "otra frase",
        category: "Vehículo ligero",
        vehicle_system: "Motor",
        subsystem: "Bombas",
        product: "Bomba de aceite",
        description: "Párrafo ya escrito"
      )
      source_row = create(
        :source_row,
        datasheet: upload,
        part_number: "RM-152",
        description: "DM-152 NISSAN PICKUP 76/14",
        manufacturer: "Rexite",
        item_group: "BOMBA DE ACEITE"
      )

      expect(described_class.new(part_store: part_store, source_row: source_row).call).to eq(:attached)

      part = Part.find_by(part_reference: "RM-152")
      expect(part.datasheet).to eq(sheet)
      expect(part).to have_attributes(
        brand: "Rexite",
        item_group: "BOMBA DE ACEITE",
        category: "Vehículo ligero",
        vehicle_system: "Motor",
        subsystem: "Bombas",
        product: "Bomba de aceite",
        description: "Párrafo ya escrito"
      )
    end

    it "creates nothing when no candidate has a datasheet" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      source_row = create(
        :source_row,
        datasheet: upload,
        part_number: "RM-152",
        description: "DM-152 NISSAN PICKUP 76/14"
      )

      expect(described_class.new(part_store: part_store, source_row: source_row).call).to eq(:missing)
      expect(part_store.datasheets.where.not(equivalent: nil)).to be_empty
      expect(Part.count).to eq(0)
    end
  end

  def create_part(datasheet, **attributes)
    create(:part, datasheet: datasheet, **attributes)
  end
end
