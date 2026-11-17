class Datasheet::Research::PageLists
  Lists = Data.define(
    :part_number, :subsystem, :product, :description,
    :applications, :interchanges, :attributes, :unconfirmed_tokens
  ) do
    def any?
      applications.any? || interchanges.any? || attributes.any? { |row| row.name.present? || row.value.present? }
    end
  end

  ApplicationRow = Data.define(
    :manufacturer, :model, :submodel, :start_year, :end_year,
    :liters, :engine_cc, :engine_cid, :engine_cylinders, :block, :fuel_type,
    :market
  )

  InterchangeRow = Data.define(:number, :brand, :origin)
  AttributeRow = Data.define(:attribute_class, :name, :unit, :value)
  VEHICLE_WORD = /\A(?:[[:alnum:]][[:alnum:]\-\/]*|&)\z/
  VEHICLE_STOP_WORD = /\A(or|major|minor|engine|engines|code|across|part|number|kit|kits|lifter|lifters|plastic|piston|pistons|pump|pumps|gasket|gaskets|chain|chains|valve|valves)\z/i
  UNCONFIRMED_LIST = /
    not\s+confirmed |
    unconfirmed |
    does\s+not\s+correspond |
    do\s+not\s+correspond |
    does\s+not\s+match |
    not\s+established |
    not\s+a\s+standard |
    are\s+examples |
    likely\s+a\s+(?:third-party|typo|warehouse|internal) |
    no\s+corresponde |
    no\s+est[aá]n?\s+confirmad |
    no\s+confirmad |
    no\s+est[aá]\s+establecid |
    son\s+ejemplos
  /ix

  def initialize(body:, phrase:, source_row:, overview: "", rewrite: Datasheet::Research::PageRewrite.new)
    @body = body.to_s
    @overview = overview.to_s
    @phrase = phrase
    @source_row = source_row
    @rewrite = rewrite
    @model_texts = []
  end

  def call
    read = read_lists
    @from_page = read.applications.any?
    read = publish(read) if @from_page
    read = without_lists(read) unless @from_page
    read.with(unconfirmed_tokens: unconfirmed_tokens(read))
  end

  def from_page?
    @from_page == true
  end

  def from_model?
    @from_model == true
  end

  private

  def read_lists
    read = accepted_rows(Datasheet::Research::PageTables.new(@body).call)
    read = add_catalog(read) unless read.applications.any?
    read = add_model(read, @body) unless read.applications.any?
    read = add_model(read, @overview) unless read.applications.any?
    read
  end

  def accepted_rows(lists)
    applications = publishable_applications(lists.applications)
    return lists.with(applications: [], interchanges: [], attributes: [], description: "") if applications.empty?

    lists.with(
      applications: applications,
      interchanges: lists.interchanges.select { |row| kept_interchange?(row, lists.part_number) },
      attributes: lists.attributes.select { |row| attribute?(row) }
    )
  end

  def publish(lists)
    add_oversize(complete_engine(add_phrase_interchanges(lists)))
  end

  def add_catalog(lists)
    catalog = Datasheet::Research::CatalogRows.new(@body)
    candidate = @phrase.candidates.find { |item| catalog.confirms?(item) }
    return lists if candidate.nil?

    applications = publishable_applications(catalog.applications_for(candidate))
    return lists if applications.empty?

    lists.with(
      part_number: lists.part_number.presence || candidate,
      applications: applications
    )
  end

  def add_model(lists, text)
    plain = transcription_text(text)
    return lists if plain.blank? || @model_texts.include?(plain)
    return lists unless @phrase.candidates.any? { |candidate| Datasheet::Research::Phrase.mentioned?(plain, candidate) }
    return lists unless transcribable?(plain)

    @model_texts << plain
    rewritten = usable(@rewrite.call(plain))
    return lists unless rewritten.any?

    @from_model = true
    lists.with(
      part_number: lists.part_number.presence || rewritten.part_number,
      subsystem: rewritten.subsystem.presence || lists.subsystem,
      product: rewritten.product.presence || lists.product,
      description: rewritten.description.presence || lists.description,
      applications: rewritten.applications,
      interchanges: rewritten.interchanges,
      attributes: rewritten.attributes
    )
  end

  def transcription_text(text)
    Datasheet::Research::CatalogRows.new(text).excerpt(@phrase.candidates)
  end

  def transcribable?(text)
    text.match?(/\b(?:#{Datasheet::Research::Phrase::VEHICLE_BRANDS.join("|")})\b/i) &&
      text.scan(/\b(?:19|20)\d{2}\b/).any? { |year| (1950..2030).cover?(year.to_i) }
  end

  def usable(lists)
    return lists.with(applications: [], interchanges: [], attributes: []) if lists.description.to_s.match?(UNCONFIRMED_LIST)

    lists.with(
      applications: publishable_applications(lists.applications),
      interchanges: lists.interchanges.select { |row| kept_interchange?(row, lists.part_number) },
      attributes: lists.attributes.select { |row| attribute?(row) }
    )
  end

  def publishable_applications(rows)
    unique_applications(rows.select { |row| application?(row) })
  end

  def unique_applications(rows)
    rows.uniq { |row|
      [
        row.manufacturer, row.model, row.submodel, row.start_year, row.end_year,
        row.liters, row.engine_cc, row.engine_cid, row.engine_cylinders, row.block,
        row.fuel_type, row.market
      ]
    }
  end

  def kept_interchange?(row, part_number)
    number = row.number.to_s.squish
    number.present? && !own_number?(number, part_number)
  end

  def add_phrase_interchanges(lists)
    extra = @phrase.candidates.filter_map { |candidate|
      next if own_number?(candidate, lists.part_number)
      next if lists.interchanges.any? { |row| same_interchange?(row.number, candidate) }

      InterchangeRow.new(number: candidate, brand: "", origin: "Aftermarket")
    }
    lists.with(interchanges: lists.interchanges + extra)
  end

  def own_number?(number, part_number)
    token = number.to_s.split.first
    [ part_number, @source_row.part_number, part_base(@source_row.part_number) ].any? { |item|
      item.present? && (same_interchange?(number, item) || same_interchange?(token, item))
    }
  end

  def same_interchange?(number, other)
    Datasheet::Research::Phrase.same_number?(number, other)
  end

  def part_base(value)
    value.to_s.sub(/\+\d+(?:\.\d+)?\z/, "")
  end

  def application?(row)
    row.manufacturer.present? && vehicle?(row.model) && years?(row) && in_phrase_years?(row)
  end

  def vehicle?(model)
    text = model.to_s.squish
    words = text.split
    return false if words.empty? || words.size > 4 || text.include?(",")
    return false unless words.all? { |word| word.match?(VEHICLE_WORD) }

    words.none? { |word| word.match?(VEHICLE_STOP_WORD) }
  end

  def years?(row)
    start_year = year(row.start_year)
    return false if start_year.nil?

    finish = year(row.end_year)
    return false if row.end_year.present? && (finish.nil? || finish < start_year)

    true
  end

  def in_phrase_years?(row)
    span = phrase_span
    return true if span.nil?

    start_year = year(row.start_year)
    return false unless span.cover?(start_year)

    finish = year(row.end_year)
    finish.nil? || span.cover?(finish)
  end

  def phrase_span
    years = @phrase.years
    return unless years.size == 2

    first = years.first.to_i
    last = years.last.to_i
    return if last < first

    first..last
  end

  def complete_engine(lists)
    engine = @phrase.engine
    lists.with(
      applications: lists.applications.map { |row| fill_application(row, engine) },
      attributes: valve_attributes(lists.attributes, engine)
    )
  end

  def fill_application(row, engine)
    row.with(
      liters: row.liters.presence || engine.liters.to_s,
      engine_cid: row.engine_cid.presence || engine.cid.to_s,
      engine_cylinders: row.engine_cylinders.presence || engine.cylinders.to_s,
      block: row.block.presence || engine.block.to_s
    )
  end

  def valve_attributes(attributes, engine)
    return attributes if engine.valves.blank?
    return attributes if attributes.any? { |row| row.name.to_s.match?(/v[aá]lvul|valve/i) }

    attributes + [
      AttributeRow.new(attribute_class: "Número", name: "Número de válvulas", unit: "", value: engine.valves)
    ]
  end

  def year(value)
    text = value.to_s
    return if text.blank? || !text.match?(/\A\d{4}\z/)

    number = text.to_i
    number if (1950..2030).cover?(number)
  end

  def attribute?(row)
    text = "#{row.attribute_class} #{row.name} #{row.value}"
    row.name.present? && row.value.present? &&
      !row.attribute_class.to_s.match?(/\d/) &&
      !text.match?(/\?|let me know|if you['’]d like|go to product|product viewer|approximately|aprox/i)
  end

  def without_lists(lists)
    lists.with(applications: [], interchanges: [], attributes: [])
  end

  def add_oversize(lists)
    oversize = @phrase.oversize
    return lists if oversize.blank?
    return lists if lists.attributes.any? { |row| "#{row.name} #{row.value}".include?(oversize) }

    lists.with(
      attributes: lists.attributes + [
        AttributeRow.new(attribute_class: "Sobremedida", name: "Sobremedida", unit: "", value: oversize)
      ]
    )
  end

  def unconfirmed_tokens(lists)
    confirmed = [ lists.part_number, @phrase.candidates.first, *lists.interchanges.map(&:number) ]
    @source_row.description.to_s.split(/\s+/).filter_map { |token|
      base = token.sub(/\+\d+(?:\.\d+)?\z/, "")
      next if base.blank? || !base.match?(/\d/)
      next if base.match?(/\A(\d{2}\/\d{2}|\d{4}|\d{4}\/\d{4}|\d+(?:\.\d+)?|\d+V)\z/i)
      next if confirmed.any? { |item| Datasheet::Research::Phrase.same_number?(item, base) }

      base
    }.uniq
  end
end
