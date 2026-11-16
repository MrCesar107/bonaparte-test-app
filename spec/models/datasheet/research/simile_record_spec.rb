require "rails_helper"

RSpec.describe Datasheet::Research::SimileRecord do
  describe "#call" do
    it "stores the accepted page, its lists and the part" do
      part_store = create(:part_store)
      source_row = source_row_for(part_store)

      described_class.new(
        part_store: part_store,
        source_row: source_row,
        phrase: phrase_for(source_row),
        result: hit
      ).call

      sheet = part_store.datasheets.find_by!(equivalent: "DM-152")
      part = sheet.parts.find_by!(part_reference: "RM-152")

      expect(sheet).to have_attributes(url: "https://parts.test/dm-152", status: "created")
      expect(sheet.applications.map { |row| [ row.start_year, row.end_year ] }).to eq([ [ "1986", "1988" ] ])
      expect(sheet.interchanges.map(&:number)).to eq([ "M152", "QJC20G" ])
      expect(sheet.part_attributes.map(&:value)).to eq([ "10" ])
      expect(part).to have_attributes(
        phrase: source_row.description,
        brand: "Rexite",
        category: "Vehículo ligero",
        vehicle_system: "MOTOR",
        subsystem: "BOMBAS",
        product: "BOMBA DE ACEITE DEL MOTOR",
        description: "Párrafo",
        unconfirmed_tokens: []
      )
    end

    it "uses the lists the search already read" do
      part_store = create(:part_store)
      source_row = source_row_for(part_store)
      rewrite = empty_rewrite
      ready = described_class.new(
        part_store: part_store,
        source_row: source_row,
        phrase: phrase_for(source_row),
        result: hit.with(lists: read_lists),
        rewrite: rewrite
      )

      ready.call

      sheet = part_store.datasheets.find_by!(equivalent: "DM-152")

      expect(sheet).to have_attributes(url: "https://parts.test/dm-152", status: "created")
      expect(sheet.applications.map(&:model)).to eq([ "Pickup" ])
      expect(rewrite).not_to have_received(:call)
    end

    it "does not publish a page that has no lists" do
      part_store = create(:part_store)
      source_row = source_row_for(part_store)

      described_class.new(
        part_store: part_store,
        source_row: source_row,
        phrase: phrase_for(source_row),
        result: hit("<title>DM-152 Oil Pump</title><p>sin tablas</p>"),
        rewrite: empty_rewrite
      ).call

      sheet = part_store.datasheets.find_by!(equivalent: "DM-152")

      expect(sheet).to have_attributes(url: "https://parts.test/dm-152", status: "not_found")
      expect(sheet.applications).to be_empty
      expect(sheet.interchanges).to be_empty
      expect(sheet.part_attributes).to be_empty
    end

    it "stores an empty not_found sheet when no page serves" do
      part_store = create(:part_store)
      source_row = source_row_for(part_store)

      described_class.new(
        part_store: part_store,
        source_row: source_row,
        phrase: phrase_for(source_row),
        result: :not_found
      ).call

      sheet = part_store.datasheets.find_by!(equivalent: "DM-152")

      expect(sheet).to have_attributes(url: "", status: "not_found")
      expect(sheet.applications).to be_empty
      expect(sheet.parts.find_by(part_reference: "RM-152")).to be_present
    end

    it "stores a failed sheet when the model does not respond" do
      part_store = create(:part_store)
      source_row = source_row_for(part_store)
      page_lists = instance_double(Datasheet::Research::PageLists)
      allow(Datasheet::Research::PageLists).to receive(:new).and_return(page_lists)
      allow(page_lists).to receive(:call).and_raise(Datasheet::Research::Unavailable)

      described_class.new(
        part_store: part_store,
        source_row: source_row,
        phrase: phrase_for(source_row),
        result: hit("<p>sin tablas</p>")
      ).call

      sheet = part_store.datasheets.find_by!(equivalent: "DM-152")

      expect(sheet).to have_attributes(url: "", status: "failed")
      expect(sheet.applications).to be_empty
      expect(sheet.parts.find_by(part_reference: "RM-152")).to be_present
    end

    it "attaches a new fingerprint to the saved sheet without rewriting it" do
      part_store = create(:part_store)
      sheet = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://parts.test/old")
      create(:part, datasheet: sheet, part_reference: "OLD-1", phrase: "otra frase", product: "Bomba de aceite", description: "Ya escrito")
      source_row = source_row_for(part_store)

      described_class.new(
        part_store: part_store,
        source_row: source_row,
        phrase: phrase_for(source_row),
        result: hit
      ).call

      part = Part.find_by!(part_reference: "RM-152")

      expect(sheet.reload.applications).to be_empty
      expect(sheet.url).to eq("https://parts.test/old")
      expect(part.datasheet).to eq(sheet)
      expect(part.product).to eq("Bomba de aceite")
      expect(part.description).to eq("Ya escrito")
    end
  end

  def source_row_for(part_store)
    upload = create(:datasheet, part_store: part_store)
    create(
      :source_row,
      datasheet: upload,
      part_number: "RM-152",
      description: "DM-152 QJC20G NISSAN PICKUP 76/14",
      item_group: "BOMBA DE ACEITE",
      manufacturer: "Rexite"
    )
  end

  def phrase_for(source_row)
    Datasheet::Research::Phrase.new(
      description: source_row.description,
      part_number: source_row.part_number,
      item_group: source_row.item_group
    ).call
  end

  def hit(body = page_html)
    Datasheet::Research::PageSearch::Hit.new(
      equivalent: "DM-152",
      url: "https://parts.test/dm-152",
      body: body,
      overview: ""
    )
  end

  def read_lists
    Datasheet::Research::PageLists::Lists.new(
      part_number: "DM-152",
      subsystem: "Bombas",
      product: "Bomba de aceite",
      description: "Párrafo",
      applications: [
        Datasheet::Research::PageLists::ApplicationRow.new(
          manufacturer: "Nissan", model: "Pickup", submodel: "", start_year: "1976", end_year: "2014",
          liters: "", engine_cc: "", engine_cid: "", engine_cylinders: "", block: "", fuel_type: "", market: ""
        )
      ],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def empty_rewrite
    rewrite = instance_double(Datasheet::Research::PageRewrite)
    allow(rewrite).to receive(:call).and_return(
      Datasheet::Research::PageLists::Lists.new(
        part_number: "", subsystem: "", product: "", description: "",
        applications: [], interchanges: [], attributes: [], unconfirmed_tokens: []
      )
    )
    rewrite
  end

  def page_html
    <<~HTML
      <h2>Aplicaciones</h2>
      <table>
        <tr><th>Fabricante</th><th>Modelo</th><th>Vigencia</th></tr>
        <tr><td>Nissan</td><td>D21</td><td>1986-1988</td></tr>
      </table>
      <h2>Intercambios</h2>
      <table>
        <tr><th>Número</th><th>Marca</th></tr>
        <tr><td>M152</td><td>Melling</td></tr>
      </table>
      <h2>Atributos</h2>
      <table>
        <tr><th>Clase</th><th>Atributo</th><th>Unidad</th><th>Valor</th></tr>
        <tr><td>Altura</td><td>Altura</td><td>mm</td><td>10</td></tr>
      </table>
      <dl>
        <dt>Número de parte</dt><dd>DM-152</dd>
        <dt>Producto</dt><dd>Bomba de aceite</dd>
        <dt>Subsistema</dt><dd>Bombas</dd>
        <dt>Descripción</dt><dd>Párrafo</dd>
      </dl>
    HTML
  end
end
