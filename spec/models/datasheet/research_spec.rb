require "rails_helper"
require "zip"

RSpec.describe Datasheet::Research do
  it "replaces the datasheet source rows with the Origen sheet and marks it created" do
    datasheet = create(:datasheet)
    create(:source_row, datasheet: datasheet, part_number: "OLD-1")
    create(:source_row, part_number: "KEEP-ME")

    File.open(file_fixture("origin.xlsx"), "rb") do |file|
      described_class.new(datasheet, file, search: empty_search, fetch: unused_fetch).call
    end

    rows = datasheet.source_rows

    expect(datasheet.reload).to be_created
    expect(rows.map(&:position)).to eq([ 1, 2 ])
    expect(rows.map(&:part_number)).to eq([ "DM-152", "X-200" ])
    expect(rows.first).to have_attributes(
      internal_code: "RM-152",
      part_number: "DM-152",
      description: "Nissan Tsuru bomba",
      article_description: "BOMBA DE ACEITE",
      item_group: "BOMBAS",
      manufacturer: "Rexite",
      unit: "PZA",
      position: 1,
      datasheet_id: datasheet.id
    )
    expect(rows.second).to have_attributes(
      internal_code: "RM-200",
      position: 2,
      description: nil,
      article_description: "FILTRO",
      item_group: "FILTROS",
      manufacturer: "Hastings",
      unit: nil
    )
    expect(SourceRow.where(part_number: "OLD-1")).to be_empty
    expect(SourceRow.where(part_number: "KEEP-ME")).to exist
    expect(datasheet.part_store.datasheets.find_by(equivalent: "DM-152")).to be_not_found
    expect(datasheet.part_store.datasheets.find_by(equivalent: "X-200")).to be_not_found
    expect(Part.where(part_reference: [ "DM-152", "X-200" ]).count).to eq(2)

    view = Datasheet::CatalogView.new(datasheet: datasheet).call
    expect(view.metrics).to have_attributes(references: 0, applications: 0, interchanges: 0, attributes: 0, without_sheet: 2)
  end

  it "publishes the accepted page and counts it in metrics" do
    datasheet = create(:datasheet)
    page = accepted_page
    search = instance_double(Datasheet::Research::SerpApiSearch, call: [ page.url ])
    fetch = instance_double(Datasheet::Research::PageFetch)
    allow(fetch).to receive(:call).with(page.url).and_return(page)

    File.open(file_fixture("origin.xlsx"), "rb") do |file|
      described_class.new(datasheet, file, search: search, fetch: fetch).call
    end

    part = Part.find_by!(part_reference: "DM-152")
    view = Datasheet::CatalogView.new(datasheet: datasheet).call

    expect(part.datasheet).to have_attributes(equivalent: "DM-152", url: page.url, status: "created")
    expect(part).to have_attributes(product: "Bomba de aceite", category: "Vehículo ligero", vehicle_system: "Motor")
    expect(view.metrics).to have_attributes(references: 1, applications: 3, interchanges: 1, attributes: 1, without_sheet: 1)
    expect(datasheet.part_store.datasheets.find_by(equivalent: "X-200")).to be_not_found
  end

  it "stops the remaining rows when the search account is out of credits" do
    datasheet = create(:datasheet)
    page = accepted_page
    calls = 0
    search = instance_double(Datasheet::Research::SerpApiSearch)
    allow(search).to receive(:call) do
      calls += 1
      raise Datasheet::Research::OutOfCredits if calls > 1

      [ page.url ]
    end
    fetch = instance_double(Datasheet::Research::PageFetch)
    allow(fetch).to receive(:call).with(page.url).and_return(page)

    File.open(file_fixture("origin.xlsx"), "rb") do |file|
      described_class.new(datasheet, file, search: search, fetch: fetch).call
    end

    expect(datasheet.reload).to be_created
    expect(Part.find_by(part_reference: "DM-152").datasheet).to be_created
    expect(datasheet.part_store.datasheets.find_by(equivalent: "X-200")).to be_nil
  end

  it "stores a whole number from the sheet without a decimal" do
    datasheet = create(:datasheet)
    workbook = numeric_workbook

    File.open(workbook.path) do |file|
      described_class.new(datasheet, file, search: empty_search, fetch: unused_fetch).call
    end

    expect(datasheet.source_rows.first.internal_code).to eq("6536")
    expect(datasheet.source_rows.first).to have_attributes(
      part_number: "DM-152",
      article_description: "BOMBA DE ACEITE",
      description: "Nissan Tsuru bomba"
    )
  end

  it "marks the datasheet failed when Origen has no data rows" do
    datasheet = create(:datasheet)

    File.open(file_fixture("origin_header.xlsx"), "rb") do |file|
      described_class.new(datasheet, file).call
    end

    expect(datasheet.reload).to be_failed
    expect(datasheet.source_rows).to be_empty
  end

  it "leaves the datasheet pending when the workbook has no Origen sheet" do
    datasheet = create(:datasheet)

    expect {
      File.open(file_fixture("missing_origin.xlsx"), "rb") do |file|
        described_class.new(datasheet, file).call
      end
    }.to raise_error(RangeError, "sheet 'Origen' not found")

    expect(datasheet.reload).to be_pending
  end

  def numeric_workbook
    file = Tempfile.new([ "origin", ".xlsx" ])
    file.close
    FileUtils.cp(file_fixture("origin.xlsx"), file.path)
    path = file.path
    Zip::File.open(path) do |zip|
      sheet = zip.read("xl/worksheets/sheet1.xml")
      sheet.sub!(
        '<c r="A2" t="inlineStr"><is><t>RM-152</t></is></c>',
        '<c r="A2"><v>6536</v></c>'
      )
      zip.get_output_stream("xl/worksheets/sheet1.xml") { |output| output.write(sheet) }
    end
    file
  end

  def empty_search
    search = instance_double(Datasheet::Research::SerpApiSearch)
    allow(search).to receive(:call).and_return([])
    search
  end

  def unused_fetch
    fetch = instance_double(Datasheet::Research::PageFetch)
    allow(fetch).to receive(:call)
    fetch
  end

  def accepted_page
    Datasheet::Research::PageSearch::Page.new(
      url: "https://parts.test/dm-152",
      part_number: "DM-152",
      product_count: 1,
      group: "Bomba de aceite",
      interchange_numbers: [],
      body: accepted_html
    )
  end

  def accepted_html
    <<~HTML
      <h2>Aplicaciones</h2>
      <table>
        <tr><th>Modelo</th><th>Vigencia</th></tr>
        <tr><td>D21</td><td>1986-1988</td></tr>
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
