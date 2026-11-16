require "rails_helper"

RSpec.describe Datasheet::Research::PageLists do
  describe "#call" do
    it "keeps the table lists and does not call the model" do
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call)

      lists = described_class.new(
        body: "<h2>Aplicaciones</h2><table><tr><th>Modelo</th></tr><tr><td>D21</td></tr></table>",
        phrase: phrase("DM-152 QJC20G NISSAN PICKUP 76/14"),
        source_row: build(:source_row, description: "DM-152 QJC20G NISSAN PICKUP 76/14"),
        rewrite: rewrite
      ).call

      expect(lists.applications.map(&:model)).to eq([ "D21" ])
      expect(lists.unconfirmed_tokens).to eq([ "QJC20G" ])
      expect(rewrite).not_to have_received(:call)
    end

    it "keeps empty lists when the page has no tables" do
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call)
      body = "<p>texto de la ficha</p>"

      lists = described_class.new(
        body: body,
        phrase: phrase("DM-152 QJC20G NISSAN PICKUP 1.8 76/14"),
        source_row: build(:source_row, description: "DM-152 QJC20G NISSAN PICKUP 1.8 76/14"),
        rewrite: rewrite
      ).call

      expect(rewrite).not_to have_received(:call)
      expect(lists.applications).to be_empty
      expect(lists.unconfirmed_tokens).to eq([ "QJC20G" ])
    end

    it "asks the model to read an overview that names the candidate" do
      overview = "HL7011 Chevrolet AFM desde 2007"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(overview).and_return(model_lists)
      reader = described_class.new(
        body: "<p>texto de la ficha</p>",
        overview: overview,
        phrase: phrase("HL7011 CHEVROLET 99/23", "HL-7025S", "PUNTERIAS"),
        source_row: build(:source_row, description: "HL7011 CHEVROLET 99/23"),
        rewrite: rewrite
      )

      expect(reader.call.applications.first).to have_attributes(
        manufacturer: "Chevrolet", model: "LS", start_year: "2007"
      )
      expect(reader).to be_from_page
    end

    it "drops a transcription whose model is not a vehicle" do
      overview = "HL7011 Chevrolet Engine Across 7011"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(overview).and_return(engine_across_lists)
      reader = described_class.new(
        body: "<p>texto de la ficha</p>",
        overview: overview,
        phrase: phrase("HL7011 CHEVROLET 99/23", "HL-7025S", "PUNTERIAS"),
        source_row: build(:source_row, description: "HL7011 CHEVROLET 99/23"),
        rewrite: rewrite
      )

      expect(reader.call.applications).to be_empty
      expect(reader).not_to be_from_page
    end

    it "keeps a vehicle range and drops a question attribute" do
      body = "<p>83-301 aparece en el texto</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(body).and_return(silverado_lists)
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18"),
        rewrite: rewrite
      )

      lists = reader.call

      expect(lists.applications.map(&:model)).to eq([ "Silverado 1500" ])
      expect(lists.applications.first).to have_attributes(start_year: "2014", end_year: "2018")
      expect(lists.attributes.map(&:name)).to eq([ "Ranura" ])
      expect(lists.interchanges.map(&:number)).to eq([ "DM-152" ])
      expect(reader).to be_from_page
    end

    it "does not send the overview when the page already has an application" do
      body = "<p>83-301 aparece en el texto</p>"
      overview = "83-301 texto del overview"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(body).and_return(silverado_lists)
      allow(rewrite).to receive(:call).with(overview)
      reader = described_class.new(
        body: body,
        overview: overview,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18"),
        rewrite: rewrite
      )

      expect(reader.call.applications.map(&:model)).to eq([ "Silverado 1500" ])
      expect(rewrite).not_to have_received(:call).with(overview)
    end

    it "does not keep a catalog row whose model is not a vehicle" do
      body = "<p>QJC20G Nissan Engine Code 7954</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).and_return(empty_lists(part_number: "", product: ""))
      reader = described_class.new(
        body: body,
        phrase: phrase("QJC20G NISSAN PICKUP 89/03", "FSX-5840301", "JUEGO DE EMPAQUES"),
        source_row: build(:source_row, description: "QJC20G NISSAN PICKUP 89/03"),
        rewrite: rewrite
      )

      expect(reader.call.applications).to be_empty
      expect(reader).not_to be_from_page
      expect(rewrite).to have_received(:call).with(body)
    end

    it "drops a transcription that says the applications are not confirmed" do
      body = "<p>QJC20G aparece en el texto</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(body).and_return(
        silverado_lists.with(
          part_number: "QJC20G",
          description: "QJC20G does not correspond to a standard code. The listed applications are examples, not confirmed fitments."
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("QJC20G NISSAN PICKUP 89/03", "FSX-5840301", "JUEGO DE EMPAQUES"),
        source_row: build(:source_row, description: "QJC20G NISSAN PICKUP 89/03"),
        rewrite: rewrite
      )

      lists = reader.call

      expect(lists.applications).to be_empty
      expect(lists.interchanges).to be_empty
      expect(lists.attributes).to be_empty
      expect(reader).not_to be_from_page
    end

    it "does not publish interchanges when there is no vehicle application" do
      body = "<p>83-301 aparece en el texto</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(body).and_return(
        empty_lists(part_number: "83-301", product: "Oregon 83-301 Oil Filter").with(
          interchanges: [ described_class::InterchangeRow.new(number: "15400-PFB-004", brand: "Honda", origin: "Aftermarket") ],
          attributes: [ described_class::AttributeRow.new(attribute_class: "", name: "Thread", unit: "mm", value: "20 x 1.5") ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        rewrite: rewrite
      )

      lists = reader.call

      expect(lists.applications).to be_empty
      expect(lists.interchanges).to be_empty
      expect(lists.attributes).to be_empty
      expect(reader).not_to be_from_page
    end

    it "reads a catalog row when the page has no tables" do
      reader = described_class.new(
        body: "<p>FS-001225 NISSAN PICKUP 1989-2003</p>",
        phrase: phrase("FS-001225 NISSAN PICKUP 89/03", "FSX-5840301", "JUEGO DE EMPAQUES"),
        source_row: build(:source_row, description: "FS-001225 NISSAN PICKUP 89/03"),
        rewrite: unused_rewrite
      )

      expect(reader.call.applications.first).to have_attributes(
        manufacturer: "Nissan",
        model: "Pickup",
        start_year: "1989",
        end_year: "2003"
      )
      expect(reader).to be_from_page
    end

    it "adds the oversize only when the page does not already list it" do
      listed = described_class.new(
        body: "#{application_table}<h2>Atributos</h2><table><tr><th>Atributo</th><th>Valor</th></tr><tr><td>Sobremedida</td><td>+20</td></tr></table>",
        phrase: phrase("SP26-329R/L+20 CHEVROLET SILVERADO", "SP26-329R/L+20", "PISTON"),
        source_row: build(:source_row, description: "SP26-329R/L+20 CHEVROLET SILVERADO"),
        rewrite: unused_rewrite
      ).call
      missing = described_class.new(
        body: application_table,
        phrase: phrase("SP26-329R/L+20 CHEVROLET SILVERADO", "SP26-329R/L+20", "PISTON"),
        source_row: build(:source_row, description: "SP26-329R/L+20 CHEVROLET SILVERADO"),
        rewrite: unused_rewrite
      ).call

      expect(listed.attributes.map(&:value)).to eq([ "+20" ])
      expect(missing.attributes.map(&:value)).to eq([ "+20" ])
      expect(missing.attributes.first).to have_attributes(attribute_class: "Sobremedida", name: "Sobremedida")
    end
  end

  def phrase(description, part_number = "RM-152", item_group = "BOMBA DE ACEITE")
    Datasheet::Research::Phrase.new(description: description, part_number: part_number, item_group: item_group).call
  end

  def empty_lists(part_number:, product:)
    described_class::Lists.new(
      part_number: part_number,
      subsystem: "",
      product: product,
      description: "",
      applications: [],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def model_lists
    described_class::Lists.new(
      part_number: "HL7011",
      subsystem: "",
      product: "Puntería",
      description: "",
      applications: [
        described_class::ApplicationRow.new(
          manufacturer: "Chevrolet", model: "LS", submodel: "", start_year: "2007", end_year: "",
          liters: "", engine_cc: "", engine_cid: "", engine_cylinders: "", block: "", fuel_type: "", market: ""
        )
      ],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def engine_across_lists
    described_class::Lists.new(
      part_number: "HL7011",
      subsystem: "",
      product: "",
      description: "",
      applications: [
        application_row(manufacturer: "Chevrolet", model: "Engine Across", start_year: "7011")
      ],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def silverado_lists
    described_class::Lists.new(
      part_number: "83-301",
      subsystem: "",
      product: "Pistón",
      description: "",
      applications: [
        application_row(manufacturer: "Chevrolet", model: "Engine Across", start_year: "7011"),
        application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018")
      ],
      interchanges: [
        described_class::InterchangeRow.new(number: "", brand: "", origin: "Aftermarket"),
        described_class::InterchangeRow.new(number: "DM-152", brand: "", origin: "Aftermarket")
      ],
      attributes: [
        described_class::AttributeRow.new(
          attribute_class: "If you'd like to narrow this down, please let me know:",
          name: "Pregunta",
          unit: "",
          value: "Which engine size do you have?"
        ),
        described_class::AttributeRow.new(attribute_class: "Medida", name: "Ranura", unit: "mm", value: "1.2")
      ],
      unconfirmed_tokens: []
    )
  end

  def application_row(manufacturer:, model:, start_year:, end_year: "")
    described_class::ApplicationRow.new(
      manufacturer: manufacturer, model: model, submodel: "", start_year: start_year, end_year: end_year,
      liters: "", engine_cc: "", engine_cid: "", engine_cylinders: "", block: "", fuel_type: "", market: ""
    )
  end

  def unused_rewrite
    rewrite = double("rewrite")
    allow(rewrite).to receive(:call)
    rewrite
  end

  def application_table
    "<h2>Aplicaciones</h2><table><tr><th>Modelo</th></tr><tr><td>Silverado</td></tr></table>"
  end
end
