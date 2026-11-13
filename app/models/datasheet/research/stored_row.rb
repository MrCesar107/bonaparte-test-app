class Datasheet::Research::StoredRow
  def initialize(part_store:, source_row:)
    @part_store = part_store
    @source_row = source_row
  end

  def call
    return :skipped if stored_part?

    sheet = stored_datasheet
    return :missing unless sheet

    attach(sheet)
    :attached
  end

  private

  def phrase
    @phrase ||= Datasheet::Research::Phrase.new(
      description: @source_row.description,
      part_number: @source_row.part_number,
      item_group: @source_row.item_group
    ).call
  end

  def stored_datasheet
    phrase.candidates.each do |candidate|
      next if candidate.blank?

      sheet = @part_store.datasheets.find_by(equivalent: candidate)
      return sheet if sheet
    end

    nil
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

  def attach(datasheet)
    template = datasheet.parts.order(:id).first

    datasheet.parts.create!(
      part_reference: @source_row.part_number,
      phrase: @source_row.description,
      fingerprint: fingerprint,
      brand: @source_row.manufacturer,
      item_group: @source_row.item_group,
      category: template&.category,
      vehicle_system: template&.vehicle_system,
      subsystem: template&.subsystem,
      product: template&.product,
      description: template&.description,
    )
  end
end
