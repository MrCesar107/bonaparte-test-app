require "rails_helper"

RSpec.describe Datasheet::Research::PageLists do
  describe "#call" do
    it "keeps the table lists and does not call the model" do
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call)

      lists = described_class.new(
        body: "<h2>Aplicaciones</h2><table><tr><th>Fabricante</th><th>Modelo</th><th>Vigencia</th></tr><tr><td>Nissan</td><td>D21</td><td>1986-1988</td></tr></table>",
        phrase: phrase("DM-152 QJC20G NISSAN PICKUP 76/14", "DM-152"),
        source_row: build(:source_row, description: "DM-152 QJC20G NISSAN PICKUP 76/14", part_number: "DM-152"),
        rewrite: rewrite
      ).call

      expect(lists.applications.map(&:model)).to eq([ "D21" ])
      expect(lists.interchanges.map(&:number)).to eq([ "QJC20G" ])
      expect(lists.unconfirmed_tokens).to eq([])
      expect(rewrite).not_to have_received(:call)
    end

    it "asks the model when the table rows are not vehicles" do
      body = <<~HTML
        <p>HL7011 aparece en el texto</p>
        <h2>Aplicaciones</h2>
        <table>
          <tr><th>Fabricante</th><th>Modelo</th><th>Vigencia</th></tr>
          <tr><td>GM</td><td>Plastic Lifter</td><td>2019</td></tr>
          <tr><td>GM</td><td>Plastic Lifter</td><td>2019</td></tr>
        </table>
      HTML
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(model_lists)
      reader = described_class.new(
        body: body,
        phrase: phrase("HL7011 CHEVROLET 99/23", "HL-7025S", "PUNTERIAS"),
        source_row: build(:source_row, description: "HL7011 CHEVROLET 99/23", part_number: "HL-7025S"),
        rewrite: rewrite
      )

      expect(reader.call.applications.map(&:model)).to eq([ "LS" ])
      expect(rewrite).to have_received(:call).with(shown(body))
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
      allow(rewrite).to receive(:call).with(shown(overview)).and_return(model_lists)
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
      overview = "HL7011 Chevrolet Engine Across 2007"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(overview)).and_return(engine_across_lists)
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
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(silverado_lists)
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        rewrite: rewrite
      )

      lists = reader.call

      expect(lists.applications.map(&:model)).to eq([ "Silverado 1500" ])
      expect(lists.applications.first).to have_attributes(start_year: "2014", end_year: "2018")
      expect(lists.attributes.map(&:name)).to eq([ "Ranura" ])
      expect(lists.interchanges.map(&:number)).to eq([ "DM-152" ])
      expect(reader).to be_from_page
    end

    it "does not ask the model when the text has no vehicle year" do
      body = "<p>83-301 aparece en el texto</p><script>Nissan 2014</script>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call)
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        rewrite: rewrite
      )

      expect(reader.call.applications).to be_empty
      expect(rewrite).not_to have_received(:call)
    end

    it "sends the visible text around the part number" do
      padding = "menu " * 4_000
      body = "<script>tracking-pixel</script><p>#{padding}83-301 Chevrolet 2014</p>"
      received = nil
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call) do |text|
        received = text
        silverado_lists
      end
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        rewrite: rewrite
      )

      reader.call

      expect(received).to include("83-301")
      expect(received).to include("Chevrolet")
      expect(received).to include("2014")
      expect(received).not_to include("tracking-pixel")
      expect(received.length).to be < padding.length
    end

    it "does not send the overview when the page already has an application" do
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      overview = "83-301 texto del overview"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(silverado_lists)
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
      expect(rewrite).not_to have_received(:call)
    end

    it "drops a transcription that says the applications are not confirmed" do
      body = "<p>QJC20G aparece en el texto Nissan 1989</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
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

    it "drops a transcription that says the part number does not match" do
      body = "<p>QJC20G aparece en el texto Nissan 1989</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        empty_lists(part_number: "QJC20G", product: "Full gasket set").with(
          description: 'The part code "QJC20G" does not match a standard Nissan factory part number. Its compatibility is not established.',
          applications: [
            application_row(manufacturer: "Nissan", model: "240SX", start_year: "1989", end_year: "1997"),
            application_row(manufacturer: "Nissan", model: "300ZX", start_year: "1990", end_year: "1996")
          ],
          interchanges: [ described_class::InterchangeRow.new(number: "FGS6007", brand: "DNJ", origin: "Aftermarket") ]
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

    it "keeps a piston list that only disclaims other part numbers" do
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        empty_lists(part_number: "83-301", product: "Engine piston set").with(
          description: "Piston set for the Silverado 1500. Other GM numbers are not identified as direct replacements.",
          applications: [
            application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018")
          ],
          attributes: [
            described_class::AttributeRow.new(attribute_class: "Dimensions", name: "Cylinder Bore Diameter", unit: "mm", value: "99.60")
          ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18"),
        rewrite: rewrite
      )

      lists = reader.call

      expect(lists.applications.map(&:model)).to eq([ "Silverado 1500" ])
      expect(lists.attributes.map(&:value)).to eq([ "99.60" ])
      expect(reader).to be_from_page
    end

    it "drops an interchange that repeats the searched number" do
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        empty_lists(part_number: "83-301", product: "Pistón").with(
          applications: [
            application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018")
          ],
          interchanges: [
            described_class::InterchangeRow.new(number: "83-301", brand: "SPQ", origin: "Aftermarket"),
            described_class::InterchangeRow.new(number: "83-301 00", brand: "SPQ", origin: "Aftermarket"),
            described_class::InterchangeRow.new(number: "FGS6007", brand: "DNJ", origin: "Aftermarket")
          ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        rewrite: rewrite
      )

      expect(reader.call.interchanges.map(&:number)).to eq([ "FGS6007" ])
    end

    it "drops a model that is a sentence fragment" do
      body = "<p>FS-001225 aparece en el texto Nissan 1989</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        empty_lists(part_number: "FS-001225", product: "Empaque").with(
          applications: [
            application_row(manufacturer: "Nissan", model: "Or Major", start_year: "1989", end_year: "2003"),
            application_row(manufacturer: "GM", model: ") V8 Engines", start_year: "2007", end_year: "2019")
          ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("FS-001225 NISSAN PICKUP 89/03", "FSX-5840301", "JUEGO DE EMPAQUES"),
        source_row: build(:source_row, description: "FS-001225 NISSAN PICKUP 89/03"),
        rewrite: rewrite
      )

      expect(reader.call.applications).to be_empty
      expect(reader).not_to be_from_page
    end

    it "keeps a vehicle name with a number or an ampersand" do
      body = "<p>9-0511S aparece en el texto Chrysler 2011</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        empty_lists(part_number: "9-0511S", product: "Kit").with(
          applications: [
            application_row(manufacturer: "Nissan", model: "240SX", start_year: "1989", end_year: "1998"),
            application_row(manufacturer: "Chrysler", model: "Town & Country", start_year: "2011", end_year: "2013"),
            application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018")
          ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("9-0511S CHRYSLER DURANGO 11/13", "TK1283-1", "KIT DE DISTRIBUCION"),
        source_row: build(:source_row, description: "9-0511S CHRYSLER DURANGO 11/13"),
        rewrite: rewrite
      )

      expect(reader.call.applications.map(&:model)).to eq([ "Town & Country" ])
    end

    it "drops an approximate measurement and a part number used as its class" do
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        silverado_lists.with(
          attributes: [
            described_class::AttributeRow.new(attribute_class: "83-301 00", name: "External piston diameter", unit: "mm", value: "Approximately 99.6"),
            described_class::AttributeRow.new(attribute_class: "Medida", name: "Ranura", unit: "mm", value: "1.2")
          ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO 14/18", "SP26-329R", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18"),
        rewrite: rewrite
      )

      expect(reader.call.attributes.map(&:name)).to eq([ "Ranura" ])
      expect(reader).to be_from_page
    end

    it "does not publish interchanges when there is no vehicle application" do
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
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

    it "fills a blank engine from the phrase and keeps a measurement the page already gave" do
      body = "<p>83-301 aparece en el texto Chevrolet 2014</p>"
      rewrite = double("rewrite")
      allow(rewrite).to receive(:call).with(shown(body)).and_return(
        empty_lists(part_number: "83-301", product: "Pistón").with(
          applications: [
            application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018"),
            application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018"),
            application_row(manufacturer: "Chevrolet", model: "Silverado 1500", start_year: "2014", end_year: "2018").with(liters: "5.3")
          ]
        )
      )
      reader = described_class.new(
        body: body,
        phrase: phrase("83-301 CHEVROLET SILVERADO V6 262 4.3 12 VAL 14/18", "SP26-329R/L+20", "PISTONES"),
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO V6 262 4.3 12 VAL 14/18", part_number: "SP26-329R/L+20"),
        rewrite: rewrite
      )

      lists = reader.call

      expect(lists.applications.map { |row| [ row.liters, row.engine_cid, row.engine_cylinders, row.block ] }).to eq([
        [ "4.3", "262", "6", "V" ],
        [ "5.3", "262", "6", "V" ]
      ])
      expect(lists.attributes.map { |row| [ row.name, row.value ] }).to eq([ [ "Número de válvulas", "12" ], [ "Sobremedida", "+20" ] ])
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

  def shown(body)
    Datasheet::Research::CatalogRows.new(body).visible_text
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
        application_row(manufacturer: "Chevrolet", model: "Engine Across", start_year: "2007")
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
    "<h2>Aplicaciones</h2><table><tr><th>Fabricante</th><th>Modelo</th><th>Vigencia</th></tr><tr><td>Chevrolet</td><td>Silverado</td><td>2014-2018</td></tr></table>"
  end
end
