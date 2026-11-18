class Datasheet::Research::SimileRecord
  CATEGORY = "Vehículo ligero"
  VEHICLE_SYSTEM = "MOTOR"
  CATALOG_LABELS = {
    "juego de empaque" => [ "JUNTAS Y SISTEMAS DE SELLADO", "JUEGO DE EMPAQUES DE MOTOR" ],
    "bomba de aceite" => [ "BOMBAS", "BOMBA DE ACEITE DEL MOTOR" ],
    "kit de distribucion" => [ "COMPONENTES DEL TREN DE VÁLVULAS", "KIT DE CADENA DE TIEMPO" ],
    "punteria" => [ "COMPONENTES DEL TREN DE VÁLVULAS", "PUNTERÍA HIDRÁULICA" ],
    "piston" => [ "COMPONENTES DEL BLOQUE DE CILINDROS", "PISTÓN DE MOTOR" ]
  }.freeze

  def initialize(part_store:, source_row:, phrase:, result:, rewrite: Datasheet::Research::PageRewrite.new)
    @part_store = part_store
    @source_row = source_row
    @phrase = phrase
    @result = result
    @rewrite = rewrite
  end

  def call
    return if equivalent.blank?

    if hit? && !@result.lists
      sheet = @part_store.datasheets.find_by(equivalent: equivalent)
      return attach_existing(sheet) if finished?(sheet)
    end

    read = lists
    Datasheet.transaction do
      sheet = @part_store.datasheets.create_or_find_by!(equivalent: equivalent) do |record|
        record.assign_attributes(url: url, status: status)
      end
      if sheet.previously_new_record?
        insert_lists(sheet, read)
        attach_new_part(sheet, read)
      elsif finished?(sheet)
        attach_existing(sheet)
      else
        sheet.update!(url: url, status: status)
        sheet.applications.delete_all
        sheet.interchanges.delete_all
        sheet.part_attributes.delete_all
        insert_lists(sheet, read)
        attach_new_part(sheet, read)
      end
    end
  end

  private

  def finished?(sheet)
    sheet&.created? || sheet&.not_found? || sheet&.failed?
  end

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

  def insert_lists(sheet, read)
    now = Time.current
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
    template = sheet.parts.order(:id).first
    insert_part(sheet,
      part_reference: @source_row.part_number,
      phrase: @source_row.description,
      fingerprint: @source_row.fingerprint,
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
    insert_part(sheet,
      part_reference: @source_row.part_number,
      phrase: @source_row.description,
      fingerprint: @source_row.fingerprint,
      brand: @source_row.manufacturer,
      item_group: @source_row.item_group,
      category: CATEGORY,
      vehicle_system: VEHICLE_SYSTEM,
      subsystem: catalog_subsystem(read),
      product: catalog_product(read),
      description: read.description,
      unconfirmed_tokens: read.unconfirmed_tokens
    )
  end

  def insert_part(sheet, **attributes)
    row = attributes.merge(datasheet_id: sheet.id, part_store_id: sheet.part_store_id)
    inserted = Part.insert_fingerprinted([ row ], returning: Part.column_names).first
    return unless inserted

    Part.instantiate(inserted).tap { |part| part.datasheet = sheet }
  end

  def catalog_subsystem(read)
    catalog_label&.first.presence || read.subsystem
  end

  def catalog_product(read)
    catalog_label&.last.presence || read.product
  end

  def catalog_label
    item_group = @source_row.item_group
    return if item_group.blank?

    normalized = I18n.transliterate(item_group).downcase.squish
    key = CATALOG_LABELS.keys.select { |candidate| normalized.include?(candidate) }.max_by(&:length)
    CATALOG_LABELS[key]
  end
end
