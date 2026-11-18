require "rails_helper"

RSpec.describe Datasheet::CatalogView do
  describe "#call" do
    it "loads associated records only for parts referenced by the upload" do
      upload = create(:datasheet)
      matching = create(:datasheet, part_store: upload.part_store, equivalent: "DM-152", status: :created)
      unrelated = create(:datasheet, part_store: upload.part_store, equivalent: "OTHER", status: :created)
      create(:part, datasheet: matching)
      create(:part, datasheet: unrelated, part_reference: "OTHER")
      create(:source_row, datasheet: upload, part_number: "RM-152", description: "DM-152 NISSAN PICKUP")
      [ matching, unrelated ].each { |sheet| create(:application, datasheet: sheet) }
      loads = Hash.new(0)
      subscriber = ->(event) { loads[event.payload[:class_name]] += event.payload[:record_count] }

      ActiveSupport::Notifications.subscribed(subscriber, "instantiation.active_record") do
        expect(described_class.new(datasheet: upload).call.catalog.map(&:reference)).to eq([ "RM-152" ])
      end

      expect(loads.values_at("Part", "Datasheet", "Application")).to eq([ 1, 1, 1 ])
    end

    it "keeps origin rows in file order and publishes a created sheet" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://example.test")
      part = create(
        :part,
        datasheet: sheet,
        part_reference: "RM-152",
        phrase: "DM-152 NISSAN PICKUP",
        brand: "Rexite",
        category: "Vehículo ligero",
        vehicle_system: "Motor",
        subsystem: "Bombas",
        product: "Bomba de aceite",
        description: "Párrafo"
      )
      create(
        :source_row,
        datasheet: upload,
        position: 1,
        internal_code: "14481",
        part_number: "RM-152",
        description: "DM-152 NISSAN PICKUP",
        article_description: "BOMBA",
        item_group: "BOMBA DE ACEITE",
        manufacturer: "REXITE",
        unit: "PZA"
      )
      create(:application, datasheet: sheet, sort_order: 1, start_year: "1986", end_year: "1988")
      create(:interchange, datasheet: sheet, sort_order: 1)
      create(:part_attribute, datasheet: sheet, sort_order: 1)

      view = described_class.new(datasheet: upload).call

      expect(view.origin.map(&:part_number)).to eq([ "RM-152" ])
      expect(view.origin.first).to have_attributes(internal_code: "14481", unit: "PZA")
      expect(view.catalog.map(&:reference)).to eq([ "RM-152" ])
      expect(view.catalog.first).to have_attributes(brand: "Rexite", product: "Bomba de aceite", category: "Vehículo ligero")
      expect(view.applications.map(&:year)).to eq([ "1986", "1987", "1988" ])
      expect(view.applications.first).to have_attributes(reference: "RM-152", brand: "Rexite", product: "Bomba de aceite", engine_cc: "2389")
      expect(view.interchanges.first).to have_attributes(number: "DM-152", interchange_brand: "Melling", origin: "Aftermarket")
      expect(view.attributes.first).to have_attributes(name: "Altura", unit: "mm", value: "10")
      expect(view.metrics).to have_attributes(references: 1, applications: 3, interchanges: 1, attributes: 1, without_sheet: 0)
      expect(part.part_reference).to eq("RM-152")
    end

    it "publishes an open year range as one row" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "HL-7025S", status: :created, url: "https://example.test")
      create(
        :part,
        datasheet: sheet,
        part_reference: "HL-7025S",
        phrase: "ELGIN AFM",
        product: "Puntería"
      )
      create(:source_row, datasheet: upload, part_number: "HL-7025S", description: "ELGIN AFM")
      create(:application, datasheet: sheet, model: "Motores LS con AFM", start_year: "2007", end_year: nil)

      view = described_class.new(datasheet: upload).call

      expect(view.applications.map(&:year)).to eq([ "2007" ])
      expect(view.applications.first.model).to eq("Motores LS con AFM")
    end

    it "leaves a not_found sheet in origin and out of the catalog" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "X-1", status: :not_found, url: "")
      create(:part, datasheet: sheet, part_reference: "HL-1", phrase: "SIN MARCA")
      create(:source_row, datasheet: upload, part_number: "HL-1", description: "SIN MARCA")
      create(:application, datasheet: sheet, start_year: "2000", end_year: "2001")

      view = described_class.new(datasheet: upload).call

      expect(view.origin.map(&:part_number)).to eq([ "HL-1" ])
      expect(view.catalog).to be_empty
      expect(view.applications).to be_empty
      expect(view.metrics.without_sheet).to eq(1)
    end

    it "publishes one catalog row for two source rows with the same fingerprint" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://example.test")
      create(:part, datasheet: sheet, part_reference: "RM-152", phrase: "DM-152 NISSAN")
      create(:source_row, datasheet: upload, position: 1, part_number: "RM-152", description: "DM-152 NISSAN")
      create(:source_row, datasheet: upload, position: 2, part_number: "rm-152", description: "dm-152   nissan")

      view = described_class.new(datasheet: upload).call

      expect(view.origin.size).to eq(2)
      expect(view.catalog.map(&:reference)).to eq([ "RM-152" ])
      expect(view.metrics.references).to eq(1)
    end

    it "orders the catalog by reference, not by origin position" do
      part_store = create(:part_store)
      upload = create(:datasheet, part_store: part_store)
      later = create(:datasheet, part_store: part_store, equivalent: "Z-9", status: :created, url: "https://example.test/z")
      earlier = create(:datasheet, part_store: part_store, equivalent: "A-1", status: :created, url: "https://example.test/a")
      create(:part, datasheet: later, part_reference: "Z-9", phrase: "LATE")
      create(:part, datasheet: earlier, part_reference: "A-1", phrase: "EARLY")
      create(:source_row, datasheet: upload, position: 1, part_number: "Z-9", description: "LATE")
      create(:source_row, datasheet: upload, position: 2, part_number: "A-1", description: "EARLY")

      view = described_class.new(datasheet: upload).call

      expect(view.origin.map(&:part_number)).to eq([ "Z-9", "A-1" ])
      expect(view.catalog.map(&:reference)).to eq([ "A-1", "Z-9" ])
    end
  end
end
