require "json"
require "nokogiri"

class Datasheet::Research::PageTables
  SECTIONS = {
    applications: /aplicacion|application/i,
    interchanges: /intercambio|interchange/i,
    attributes: /atributo|especificacion|specification/i
  }.freeze
  HEADER_SECTIONS = {
    applications: /fabricante|make|modelo|model|a[nñ]o|year|vigencia/i,
    interchanges: /intercambio|interchange/i,
    attributes: /atributo|especificaci[oó]n|specification|valor|value/i
  }.freeze

  def initialize(body)
    @body = body
  end

  def call
    lists = table_lists
    lists = schema_lists(lists) if product_node
    return lists if lists.applications.any? || lists.interchanges.any? || lists.attributes.any?

    rows = fits_rows
    return lists if rows.empty?

    lists.with(applications: rows)
  end

  def any?
    call.then { |lists| lists.applications.any? || lists.interchanges.any? || lists.attributes.any? }
  end

  private

  def document
    @document ||= Nokogiri::HTML(@body)
  end

  def table_lists
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

  def sections
    {
      applications: table_for(:applications),
      interchanges: table_for(:interchanges),
      attributes: table_for(:attributes)
    }
  end

  def product_node
    return @product_node if defined?(@product_node)

    @product_node = document.css('script[type="application/ld+json"]').filter_map { |node| product_from(node.text) }.first
  end

  def product_from(text)
    data = JSON.parse(text)
    items = data.is_a?(Hash) && data["@graph"] ? data["@graph"] : data
    items = [ items ] unless items.is_a?(Array)
    items.find { |item| item.is_a?(Hash) && Array(item["@type"]).join(" ").match?(/Product/i) }
  rescue JSON::ParserError
    nil
  end

  def schema_lists(lists)
    lists = lists.with(
      part_number: lists.part_number.presence || product_node["sku"].presence || product_node["mpn"].to_s,
      product: lists.product.presence || product_node["name"].to_s.squish,
      description: lists.description.presence || commercial_text(product_node["description"])
    )
    return lists if lists.applications.any? || lists.interchanges.any? || lists.attributes.any?

    lists.with(
      applications: compatibility_rows(product_node["description"]),
      interchanges: product_interchanges(product_node)
    )
  end

  def fits_rows
    sentence = document.text[/Fits:\s*(.+?)\./i, 1].to_s
    sentence.split(";").flat_map { |clause| fits_clause(clause.squish) }
  end

  def fits_clause(clause)
    brands = Datasheet::Research::Phrase::VEHICLE_BRANDS.join("|")
    match = clause.match(/\A(?<years>.*?)\b(?<brand>#{brands})\b\s*(?<model>.+?)\s*\z/i)
    return [] unless match

    model = match[:model].sub(/\.\z/, "").squish
    label = Datasheet::Research::Phrase::BRAND_LABELS[match[:brand].downcase]
    year_spans(match[:years]).filter_map do |start_year, end_year|
      next if model.blank? || label.blank?

      application_row(label, model, start_year, end_year)
    end
  end

  def year_spans(text)
    text.to_s.scan(/\b(\d{4})(?:\s*-\s*(\d{4}))?\b/).map { |start_year, end_year| [ start_year, end_year.to_s ] }
  end

  def application_row(manufacturer, model, start_year, end_year)
    Datasheet::Research::PageLists::ApplicationRow.new(
      manufacturer: manufacturer, model: model, submodel: "", start_year: start_year, end_year: end_year,
      liters: "", engine_cc: "", engine_cid: "", engine_cylinders: "", block: "", fuel_type: "", market: ""
    )
  end

  def commercial_text(text)
    text.to_s.split(/aplicaci[oó]n y compatibilidad\s*:/i).first.to_s.squish
  end

  def compatibility_rows(description)
    text = description.to_s[/aplicaci[oó]n y compatibilidad:\s*(.+?)(?:referencias equivalentes|\z)/i, 1].to_s
    return [] if text.squish.blank?

    text.split(/\.\s+(?=[^:]{1,40}:)/).flat_map do |chunk|
      brand, section = chunk.split(":", 2)
      rows_for(brand.to_s.squish, section.to_s.squish.sub(/\.\s*\z/, ""))
    end
  end

  def rows_for(brand, section)
    return [] if brand.blank?

    head, = section.split(/\bcon motor\b/i, 2)
    start_year, end_year = years(section)
    liters = liters_in(section)

    head.to_s.split(/\s+y\s+|,\s+/).filter_map do |piece|
      model = piece.sub(/\(.*\z/, "").squish.sub(/[.\s]+\z/, "")
      next if model.blank?

      Datasheet::Research::PageLists::ApplicationRow.new(
        manufacturer: brand,
        model: model,
        submodel: "",
        start_year: start_year,
        end_year: end_year,
        liters: liters,
        engine_cc: "",
        engine_cid: "",
        engine_cylinders: "",
        block: "",
        fuel_type: "",
        market: ""
      )
    end
  end

  def liters_in(text)
    text.to_s[/(\d+(?:[.,]\d+)?)\s*L\b/i, 1].to_s.tr(",", ".")
  end

  def product_interchanges(product)
    numbers = Array(product["alternateName"]).map { |name| name.to_s.squish }
    numbers += prose_interchange_numbers(product["description"])
    own = [ product["sku"], product["mpn"] ]

    numbers.filter_map { |number|
      next if number.blank? || !number.match?(/\d/)
      next if own.any? { |item| Datasheet::Research::Phrase.same_number?(item, number) }

      Datasheet::Research::PageLists::InterchangeRow.new(number: number, brand: "", origin: "Aftermarket")
    }.uniq
  end

  def prose_interchange_numbers(description)
    tail = description.to_s[/referencias equivalentes\s*\/\s*intercambios:\s*(.+)\z/i, 1].to_s
    tail.scan(/[A-Z0-9][A-Z0-9.\-\/]{2,}/i)
  end

  def table_for(section)
    table_after(SECTIONS[section]) || table_with_headers(section)
  end

  def table_with_headers(section)
    document.css("table").find { |table| header_text(table).match?(HEADER_SECTIONS[section]) || interchange_headers?(section, table) }
  end

  def interchange_headers?(section, table)
    return false unless section == :interchanges

    text = header_text(table)
    text.match?(/n[uú]mero|number/i) && text.match?(/marca|brand/i)
  end

  def header_text(table)
    header_cells(table).map { |cell| cell.text.squish }.join(" ")
  end

  def header_cells(table)
    table.xpath(".//tr[1]/*[self::th or self::td]")
  end

  def table_after(pattern)
    heading = document.xpath("//*[self::h1 or self::h2 or self::h3 or self::caption]").
      find { |node| node.text.match?(pattern) }
    heading&.xpath("following::table[1]")&.first
  end

  def rows(table)
    return [] if table.nil?

    headers = header_cells(table).map { |cell| cell.text.squish.downcase }
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
