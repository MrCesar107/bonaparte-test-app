require "nokogiri"

class Datasheet::Research::PageTables
  SECTIONS = {
    applications: /aplicacion|application/i,
    interchanges: /intercambio|interchange/i,
    attributes: /atributo|especificacion|specification/i
  }.freeze

  def initialize(body)
    @body = body
  end

  def call
    tables = sections

    Datasheet::Research::PageLists::Lists.new(
      part_number: labeled("part number", "número de parte"),
      subsystem: labeled("subsystem", "subsistema"),
      product: labeled("product", "producto"),
      description: labeled("description", "descripción"),
      applications: application_rows(tables[:applications]),
      interchanges: interchange_rows(tables[:interchanges]),
      attributes: attribute_rows(tables[:attributes]),
      unconfirmed_tokens: []
    )
  end

  def any?
    call.then { |lists| lists.applications.any? || lists.interchanges.any? || lists.attributes.any? }
  end

  private

  def document
    @document ||= Nokogiri::HTML(@body)
  end

  def sections
    SECTIONS.transform_values { |pattern| table_after(pattern) }
  end

  def table_after(pattern)
    heading = document.xpath("//*[self::h1 or self::h2 or self::h3 or self::caption]").
      find { |node| node.text.match?(pattern) }
    heading&.xpath("following::table[1]")&.first
  end

  def rows(table)
    return [] if table.nil?

    headers = table.xpath(".//tr[1]/th").map { |cell| cell.text.squish.downcase }
    table.xpath(".//tr[position()>1]").filter_map do |row|
      values = row.xpath("./td").map { |cell| cell.text.squish }
      next if values.all?(&:blank?)

      headers.zip(values).to_h
    end
  end

  def application_rows(table)
    rows(table).map do |row|
      start_year, end_year = years(row["año"] || row["year"] || row["vigencia"])

      Datasheet::Research::PageLists::ApplicationRow.new(
        manufacturer: row["fabricante"] || row["make"],
        model: row["modelo"] || row["model"],
        submodel: row["submodelo"] || row["submodel"],
        start_year: start_year,
        end_year: end_year,
        liters: row["litros"] || row["liters"],
        engine_cc: row["cc"],
        engine_cid: row["cid"],
        engine_cylinders: row["cilindros"] || row["cylinders"],
        block: row["bloque"] || row["block"],
        fuel_type: row["tipo de combustible"] || row["fuel"],
        market: row["mercado"] || row["market"],
      )
    end
  end

  def years(value)
    text = value.to_s
    return [ "", "" ] if text.blank?
    return [ text[/\d{4}/].to_s, "" ] if text.match?(/desde/i)

    years = text.scan(/\d{4}/)

    [ years.first.to_s, years.second.to_s ]
  end

  def interchange_rows(table)
    rows(table).map do |row|
      brand = row["marca"] || row["brand"]

      Datasheet::Research::PageLists::InterchangeRow.new(
        number: row["número"] || row["number"] || row["intercambio"],
        brand: brand,
        origin: Datasheet::Research::Phrase::VEHICLE_BRANDS.include?(brand.to_s.downcase) && "OEM" || "Aftermarket"
      )
    end
  end

  def attribute_rows(table)
    rows(table).map do |row|
      Datasheet::Research::PageLists::AttributeRow.new(
        attribute_class: row["clase"] || row["class"],
        name: row["atributo"] || row["attribute"] || row["name"],
        unit: row["unidad"] || row["unit"],
        value: row["valor"] || row["value"]
      )
    end
  end

  def labeled(*names)
    pattern = /#{names.join("|")}/i
    node = document.xpath("//th|//dt").find { |item| item.text.match?(pattern) }
    node&.xpath("following-sibling::*[1]")&.text.to_s.squish
  end
end
