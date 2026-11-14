require "rails_helper"

RSpec.describe Datasheet::Workbook do
  it "writes one sheet for each datasheet section" do
    part_store = create(:part_store, name: "North Garage")
    upload = create(:datasheet, part_store: part_store, status: :created)
    sheet = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://example.test")
    create(
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
    create(:application, datasheet: sheet, sort_order: 1, start_year: "1986", end_year: "1987")
    create(:interchange, datasheet: sheet, sort_order: 1)
    create(:part_attribute, datasheet: sheet, sort_order: 1)
    upload.update_columns(name: "datasheet_ready")

    workbook = described_class.new(upload)
    spreadsheet = Roo::Spreadsheet.open(StringIO.new(workbook.call), extension: :xlsx)

    expect(workbook.filename).to eq("datasheet_ready.xlsx")
    expect(spreadsheet.sheets).to eq([ "Origen", "Métricas", "Aplicaciones", "Intercambios", "Atributos", "Catálogo" ])
    expect(spreadsheet.sheet("Origen").row(1)).to eq([ "Cod interno", "Número de parte", "Descripción del artículo", "Descripcion", "Grupo de articulos", "Fabricante", "Unidad" ])
    expect(spreadsheet.sheet("Origen").row(2)).to eq([ "14481", "RM-152", "BOMBA", "DM-152 NISSAN PICKUP", "BOMBA DE ACEITE", "REXITE", "PZA" ])
    expect(spreadsheet.sheet("Métricas").row(1).compact).to eq([ "Catálogo Bonaparte - North Garage" ])
    expect(spreadsheet.sheet("Métricas").row(2).compact).to eq([ "Referencias", 1 ])
    expect(spreadsheet.sheet("Métricas").row(5).compact).to eq([ "Incrementos", 2 ])
    expect(spreadsheet.sheet("Métricas").row(12).compact).to eq([ "Sin ficha", 0 ])
    expect(spreadsheet.sheet("Aplicaciones").row(2)).to include("RM-152", "Rexite", "1986")
    expect(spreadsheet.sheet("Aplicaciones").row(3)).to include("1987")
    expect(spreadsheet.sheet("Intercambios").row(2)).to include("DM-152", "Melling", "Aftermarket")
    expect(spreadsheet.sheet("Atributos").row(2)).to include("Altura", "mm", "10")
    expect(spreadsheet.sheet("Catálogo").row(2)).to eq([ "RM-152", "Rexite", "Vehículo ligero", "Motor", "Bombas", "Bomba de aceite", "Párrafo" ])
  end

  it "escapes cell text that would break the workbook" do
    part_store = create(:part_store, name: "A & B")
    upload = create(:datasheet, part_store: part_store, status: :created)
    create(:source_row, datasheet: upload, article_description: "1 < 2")

    spreadsheet = Roo::Spreadsheet.open(StringIO.new(described_class.new(upload).call), extension: :xlsx)

    expect(spreadsheet.sheet("Métricas").row(1).compact).to eq([ "Catálogo Bonaparte - A & B" ])
    expect(spreadsheet.sheet("Origen").row(2)).to include("1 < 2")
  end
end
