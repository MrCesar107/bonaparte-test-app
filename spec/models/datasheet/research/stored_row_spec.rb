require "rails_helper"

RSpec.describe Datasheet::Research::StoredRow do
  it "checks existing fingerprints in a single query for a batch" do
    upload = create(:datasheet)
    sheet = create(:datasheet, part_store: upload.part_store, equivalent: "DM-152")
    rows = Array.new(5) do |index|
      part = create_part(sheet, part_reference: "RM-#{index}")
      create(:source_row, datasheet: upload, part_number: part.part_reference, description: part.phrase)
    end
    queries = []
    subscriber = ->(event) { queries << event.payload[:sql] }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      lookup = described_class::Lookup.new(part_store: upload.part_store, source_rows: rows)
      results = rows.map do |row|
        described_class.new(part_store: upload.part_store, source_row: row, lookup: lookup).call
      end
      expect(results).to all(eq(:skipped))
    end

    expect(queries.grep(/SELECT.*FROM "parts"/)).to have_attributes(size: 1)
  end

  describe "#call" do
    it "skips a conflicting insert when another import writes the fingerprint after lookup" do
      upload = create(:datasheet)
      sheet = create(:datasheet, part_store: upload.part_store, equivalent: "DM-152")
      source_row = create(:source_row, datasheet: upload, part_number: "DM-152")
      lookup = described_class::Lookup.new(part_store: upload.part_store, source_rows: [ source_row ])

      described_class.new(part_store: upload.part_store, source_row: source_row, lookup: lookup).call
      concurrent_part = create(:part, datasheet: sheet, fingerprint: source_row.fingerprint, product: "Existing part")

      expect { lookup.flush }.not_to change(Part, :count)
      expect(Part.for_part_store(upload.part_store_id).find_by!(fingerprint: source_row.fingerprint)).to eq(concurrent_part)
    end

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
