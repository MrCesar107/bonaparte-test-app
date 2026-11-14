class Datasheet::Research::PageLists
  Lists = Data.define(
    :part_number, :subsystem, :product, :description,
    :applications, :interchanges, :attributes, :unconfirmed_tokens
  ) do
    def any?
      applications.any? || interchanges.any? || attributes.any?
    end
  end

  ApplicationRow = Data.define(
    :manufacturer, :model, :submodel, :start_year, :end_year,
    :liters, :engine_cc, :engine_cid, :engine_cylinders, :block, :fuel_type,
    :market
  )

  InterchangeRow = Data.define(:number, :brand, :origin)
  AttributeRow = Data.define(:attribute_class, :name, :unit, :value)

  def initialize(body:, phrase:, source_row:, rewrite: Datasheet::Research::PageRewrite.new)
    @body = body.to_s
    @phrase = phrase
    @source_row = source_row
    @rewrite = rewrite
  end

  def call
    read = Datasheet::Research::PageTables.new(@body).call
    @from_page = read.any?
    read = add_oversize(read)
    read.with(unconfirmed_tokens: unconfirmed_tokens(read))
  end

  def from_page?
    @from_page == true
  end

  private

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
