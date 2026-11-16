class Datasheet::Research::PageRewrite
  MODEL = "gpt-6.1-sol"

  def call(body)
    lists_from(ask(body).parsed)
  rescue RubyLLM::Error, JSON::GeneratorError
    raise Datasheet::Research::Unavailable
  end

  private

  def ask(body)
    RubyLLM.chat(model: MODEL, provider: :openai, assume_model_exists: true)
      .with_thinking(effort: :medium)
      .with_schema(Datasheet::Research::PageSchema)
      .ask(prompt(body))
  end

  def prompt(body)
    <<~TEXT
      Rewrite only the text of this page as JSON.
      Do not choose another URL or another part sheet.
      Keep the page order.
      Write the description in Spanish, in two sentences: what the part is and which engine it fits, including the measurements the page states.
      Do not mention other part numbers, variants, or what the page does not confirm.
      An application is one vehicle manufacturer, one vehicle model, and one year range.
      Copy every vehicle model the page names for this part.
      The model is only the vehicle name. It is not a sentence.
      A year range stays in start_year and end_year.
      Do not use a part number as a year.
      If the page says "since" a year and there is no end year, leave end_year as an empty string.
      When the page states submodel, liters, engine_cc, engine_cid, engine_cylinders, block, fuel_type, or market, copy those values onto every application of that engine.
      Leave any of those fields empty when the text does not state them.
      An interchange is a part number and its brand.
      An attribute is a measurement with a name and a value.
      Name attribute_class and name in Spanish.
      Split a list of ring grooves into one attribute per groove.
      Do not copy questions, shopping text, or instructions to the reader.
      If the text does not confirm that this part number fits the vehicles, return empty applications, interchanges, and attributes.
      Say that the list is not established in the description.

      #{utf8(body)}
    TEXT
  end

  def utf8(text)
    text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
  end

  def lists_from(data)
    Datasheet::Research::PageLists::Lists.new(
      part_number: data["part_number"].to_s,
      subsystem: data["subsystem"].to_s,
      product: data["product"].to_s,
      description: data["description"].to_s,
      applications: Array(data["applications"]).map { |row| application_row(row) },
      interchanges: Array(data["interchanges"]).map { |row| interchange_row(row) },
      attributes: Array(data["attributes"]).map { |row| attribute_row(row) },
      unconfirmed_tokens: []
    )
  end

  def application_row(row)
    Datasheet::Research::PageLists::ApplicationRow.new(
      manufacturer: row["manufacturer"].to_s,
      model: row["model"].to_s,
      submodel: row["submodel"].to_s,
      start_year: row["start_year"].to_s,
      end_year: row["end_year"].to_s,
      liters: row["liters"].to_s,
      engine_cc: row["engine_cc"].to_s,
      engine_cid: row["engine_cid"].to_s,
      engine_cylinders: row["engine_cylinders"].to_s,
      block: row["block"].to_s,
      fuel_type: row["fuel_type"].to_s,
      market: row["market"].to_s,
    )
  end

  def interchange_row(row)
    brand = row["brand"].to_s

    Datasheet::Research::PageLists::InterchangeRow.new(
      number: row["number"].to_s,
      brand: brand,
      origin: Datasheet::Research::Phrase::VEHICLE_BRANDS.include?(brand.downcase) && "OEM" || "Aftermarket"
    )
  end

  def attribute_row(row)
    Datasheet::Research::PageLists::AttributeRow.new(
      attribute_class: row["attribute_class"].to_s,
      name: row["name"].to_s,
      unit: row["unit"].to_s,
      value: row["value"].to_s
    )
  end
end
