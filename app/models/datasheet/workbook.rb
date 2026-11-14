require "caxlsx"

class Datasheet::Workbook
  def initialize(datasheet)
    @datasheet = datasheet
    @view = Datasheet::CatalogView.new(datasheet: datasheet).call
  end

  def call
    package = Axlsx::Package.new
    sheets.each do |sheet|
      package.workbook.add_worksheet(name: sheet[:name]) do |worksheet|
        sheet[:rows].each { |row| worksheet.add_row(row, types: cell_types(row)) }
      end
    end
    package.to_stream.read
  end

  def filename
    "#{@datasheet.name}.xlsx"
  end

  private

  def cell_types(row)
    row.map { |value| value.is_a?(Numeric) ? :integer : :string }
  end

  def sheets
    [
      { name: "Origen", rows: origin_rows },
      { name: "Métricas", rows: metric_rows },
      { name: "Aplicaciones", rows: application_rows },
      { name: "Intercambios", rows: interchange_rows },
      { name: "Atributos", rows: attribute_rows },
      { name: "Catálogo", rows: catalog_rows }
    ]
  end

  def origin_rows
    rows = [ [ "Cod interno", "Número de parte", "Descripción del artículo", "Descripcion", "Grupo de articulos", "Fabricante", "Unidad" ] ]
    @view.origin.each do |row|
      rows << [ row.internal_code, row.part_number, row.article_description, row.description, row.item_group, row.manufacturer, row.unit ]
    end
    rows
  end

  def metric_rows
    metrics = @view.metrics

    [
      [ "Catálogo Bonaparte - #{@datasheet.part_store.name}" ],
      [ "Referencias", metrics.references ],
      [ "Aplicaciones" ],
      [ "Origen", 0 ],
      [ "Incrementos", metrics.applications ],
      [ "Intercambios" ],
      [ "Origen", 0 ],
      [ "Incrementos", metrics.interchanges ],
      [ "Atributos" ],
      [ "Origen", 0 ],
      [ "Incrementos", metrics.attributes ],
      [ "Sin ficha", metrics.without_sheet ]
    ]
  end

  def application_rows
    rows = [ [ "Referencia", "Marca", "Producto", "Posición", "Fabricante", "Modelo", "Submodelo", "Año", "Litros", "CC", "CID", "Cilindros", "Bloque", "Combustible", "Mercado" ] ]
    @view.applications.each do |row|
      rows << [
        row.reference, row.brand, row.product, row.position, row.manufacturer, row.model, row.submodel,
        row.year, row.liters, row.engine_cc, row.engine_cid, row.engine_cylinders, row.block, row.fuel_type, row.market
      ]
    end
    rows
  end

  def interchange_rows
    rows = [ [ "Referencia", "Marca", "Producto", "Intercambio", "Marca intercambio", "Origen" ] ]
    @view.interchanges.each do |row|
      rows << [ row.reference, row.brand, row.product, row.number, row.interchange_brand, row.origin ]
    end
    rows
  end

  def attribute_rows
    rows = [ [ "Referencia", "Marca", "Producto", "Clase", "Atributo", "Unidad", "Valor" ] ]
    @view.attributes.each do |row|
      rows << [ row.reference, row.brand, row.product, row.attribute_class, row.name, row.unit, row.value ]
    end
    rows
  end

  def catalog_rows
    rows = [ [ "Referencia", "Marca", "Categoría", "Sistema", "Subsistema", "Producto", "Descripción" ] ]
    @view.catalog.each do |row|
      rows << [ row.reference, row.brand, row.category, row.vehicle_system, row.subsystem, row.product, row.description ]
    end
    rows
  end
end
