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
  UNCONFIRMED_LIST = /
    not\s+confirmed |
    unconfirmed |
    does\s+not\s+correspond |
    do\s+not\s+correspond |
    not\s+a\s+standard |
    are\s+examples |
    no\s+corresponde |
    no\s+est[aá]n?\s+confirmad |
    no\s+confirmad |
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
    read = add_oversize(read) if @from_page
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
    read = Datasheet::Research::PageTables.new(@body).call
    read = add_catalog(read) unless read.applications.any?
    read = add_model(read, @body) unless read.applications.any?
    read = add_model(read, @overview) unless read.applications.any?
    read
  end

  def add_catalog(lists)
    catalog = Datasheet::Research::CatalogRows.new(@body)
    candidate = @phrase.candidates.find { |item| catalog.confirms?(item) }
    return lists if candidate.nil?

    applications = catalog.applications_for(candidate).select { |row| application?(row) }
    return lists if applications.empty?

    lists.with(
      part_number: lists.part_number.presence || candidate,
      applications: applications
    )
  end

  def add_model(lists, text)
    plain = text.to_s
    return lists if plain.blank? || @model_texts.include?(plain)
    return lists unless @phrase.candidates.any? { |candidate| Datasheet::Research::Phrase.mentioned?(plain, candidate) }

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

  def usable(lists)
    return lists.with(applications: [], interchanges: [], attributes: []) if lists.description.to_s.match?(UNCONFIRMED_LIST)

    lists.with(
      applications: lists.applications.select { |row| application?(row) },
      interchanges: lists.interchanges.select { |row| row.number.present? },
      attributes: lists.attributes.select { |row| attribute?(row) }
    )
  end

  def application?(row)
    row.manufacturer.present? && vehicle?(row.model) && years?(row)
  end

  def vehicle?(model)
    text = model.to_s.squish
    return false if text.blank? || text.include?(",") || text.split.size > 4

    !text.match?(/\b(engine|code|across|part|number|kit)\b/i)
  end

  def years?(row)
    start_year = year(row.start_year)
    finish = year(row.end_year)
    return false if row.start_year.present? && start_year.nil?
    return false if row.end_year.present? && (finish.nil? || start_year.nil? || finish < start_year)

    true
  end

  def year(value)
    text = value.to_s
    return if text.blank? || !text.match?(/\A\d{4}\z/)

    number = text.to_i
    number if (1950..2030).cover?(number)
  end

  def attribute?(row)
    text = "#{row.attribute_class} #{row.name} #{row.value}"
    row.name.present? && row.value.present? && !text.match?(/\?|let me know|if you['’]d like|go to product|product viewer/i)
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
