class Datasheet::Research::SimileRecord
  CATEGORY = "Vehículo ligero"
  VEHICLE_SYSTEM = "Motor"

  def initialize(part_store:, source_row:, phrase:, result:, rewrite: Datasheet::Research::PageRewrite.new)
    @part_store = part_store
    @source_row = source_row
    @phrase = phrase
    @result = result
    @rewrite = rewrite
  end

  def call
    return if equivalent.blank?

    sheet = @part_store.datasheets.find_by(equivalent: equivalent)
    return attach_existing(sheet) if sheet&.created? || sheet&.not_found? || sheet&.failed?

    read = lists
    Datasheet.transaction do
      sheet = @part_store.datasheets.find_or_initialize_by(equivalent: equivalent)
      sheet.update!(url: url, status: status)
      replace_lists(sheet, read)
      attach_new_part(sheet, read)
    end
  end

  private

  def equivalent
    hit? ? @result.equivalent : @phrase.candidates.first
  end

  def url
    return @result.url if hit? && !@model_failed

    ""
  end

  def status
    return :failed if @model_failed
    return :created if publishable?
    return :not_found if @result == :not_found || hit?

    :failed
  end

  def publishable?
    hit? && !@model_failed && lists_from_page?
  end

  def lists_from_page?
    read = lists
    return read.applications.any? if hit? && @result.lists

    @page_lists&.from_page? == true
  end

  def hit?
    @result.is_a?(Datasheet::Research::PageSearch::Hit)
  end

  def lists
    return empty_lists unless hit?
    return @lists ||= @result.lists if @result.lists

    @page_lists ||= Datasheet::Research::PageLists.new(
      body: @result.body,
      overview: @result.overview,
      phrase: @phrase,
      source_row: @source_row,
      rewrite: @rewrite
    )
    @lists ||= @page_lists.call
  rescue Datasheet::Research::Unavailable
    @model_failed = true
    @lists = empty_lists
  end

  def empty_lists
    Datasheet::Research::PageLists::Lists.new(
      part_number: "",
      subsystem: "",
      product: "",
      description: "",
      applications: [],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def replace_lists(sheet, read)
    now = Time.current
    sheet.applications.delete_all
    sheet.interchanges.delete_all
    sheet.part_attributes.delete_all
    insert_rows(sheet.applications, read.applications) do |row, index|
      row.to_h.merge(sort_order: index, position: "", datasheet_id: sheet.id, created_at: now, updated_at: now)
    end
    insert_rows(sheet.interchanges, read.interchanges) do |row, index|
      row.to_h.merge(sort_order: index, datasheet_id: sheet.id, created_at: now, updated_at: now)
    end
    insert_rows(sheet.part_attributes, read.attributes) do |row, index|
      row.to_h.merge(sort_order: index, datasheet_id: sheet.id, created_at: now, updated_at: now)
    end
  end

  def insert_rows(relation, rows)
    return if rows.empty?

    relation.insert_all(rows.each_with_index.map { |row, index| yield(row, index + 1) })
  end

  def attach_existing(sheet)
    return if stored_part?

    template = sheet.parts.order(:id).first
    sheet.parts.create!(
      part_reference: @source_row.part_number,
      phrase: @source_row.description,
      fingerprint: fingerprint,
      brand: @source_row.manufacturer,
      item_group: @source_row.item_group,
      category: template&.category || CATEGORY,
      vehicle_system: template&.vehicle_system || VEHICLE_SYSTEM,
      subsystem: template&.subsystem,
      product: template&.product,
      description: template&.description,
      unconfirmed_tokens: template&.unconfirmed_tokens || []
    )
  end

  def attach_new_part(sheet, read)
    return if stored_part?

    sheet.parts.create!(
      part_reference: @source_row.part_number,
      phrase: @source_row.description,
      fingerprint: fingerprint,
      brand: @source_row.manufacturer,
      item_group: @source_row.item_group,
      category: CATEGORY,
      vehicle_system: VEHICLE_SYSTEM,
      subsystem: read.subsystem,
      product: read.product,
      description: read.description,
      unconfirmed_tokens: read.unconfirmed_tokens
    )
  end

  def stored_part?
    Part.joins(:datasheet).exists?(
      fingerprint: fingerprint,
      datasheets: { part_store_id: @part_store.id }
    )
  end

  def fingerprint
    "#{@source_row.part_number} #{@source_row.description}".upcase.squish
  end
end
