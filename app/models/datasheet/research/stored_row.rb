# It reuses a store's saved research for an input row, avoiding duplicate parts and new searches.

# Skips an existing fingerprint or links a new part to the first saved candidate datasheet.

# Copies catalog labels from a saved part, including when the prior research found no result.

# Returns a missing outcome only when the row needs a new external search.
class Datasheet::Research::StoredRow
  class Lookup
    def initialize(part_store:, source_rows:)
      fingerprints = source_rows.map(&:fingerprint).uniq
      @stored_fingerprints = Part.for_part_store(part_store.id).where(fingerprint: fingerprints).pluck(:fingerprint).to_set
      @pending_parts = []
      @phrases = source_rows.reject { |row| stored?(row) }.to_h do |row|
        phrase = Datasheet::Research::Phrase.new(
          description: row.description, part_number: row.part_number, item_group: row.item_group
        ).call
        [ row, phrase ]
      end

      candidates = @phrases.values.flat_map(&:candidates).compact_blank.uniq
      @sheets = part_store.datasheets.where(equivalent: candidates).index_by(&:equivalent)
      @templates = @sheets.values.to_h { |sheet| [ sheet.id, nil ] }
      first_parts = Part.where(datasheet_id: @templates.keys)
        .select("DISTINCT ON (parts.datasheet_id) parts.*").order(:datasheet_id, :id)
      @templates.merge!(first_parts.index_by(&:datasheet_id))
    end

    def stored?(row)
      @stored_fingerprints.include?(row.fingerprint)
    end

    def phrase_for(row)
      @phrases.fetch(row)
    end

    def sheet_for(row)
      candidate = phrase_for(row).candidates.find { |number| @sheets.key?(number) }
      @sheets[candidate]
    end

    def template_for(sheet)
      @templates.fetch(sheet.id) { @templates[sheet.id] = sheet.parts.order(:id).first }
    end

    def remember(part)
      sheet = part.datasheet
      @sheets[sheet.equivalent] = sheet
      @stored_fingerprints.add(part.fingerprint)
      @templates[sheet.id] ||= part if @templates.key?(sheet.id)
    end

    def stage_part(sheet, attributes)
      @pending_parts << attributes.merge(datasheet_id: sheet.id, part_store_id: sheet.part_store_id)
      @stored_fingerprints.add(attributes.fetch(:fingerprint))
      @templates[sheet.id] ||= Part.new(attributes)
    end

    def flush(returning: false)
      return if @pending_parts.empty?

      # Concurrent imports acquire conflicting fingerprint keys in the same order.
      rows = @pending_parts.sort_by { |part| part.fetch(:fingerprint) }
      Part.insert_fingerprinted(rows, returning: returning).tap { @pending_parts.clear }
    end
  end

  def initialize(part_store:, source_row:, lookup: nil)
    @source_row = source_row
    @batched = lookup.present?
    @lookup = lookup || Lookup.new(part_store: part_store, source_rows: [ source_row ])
  end

  def call
    return :skipped if @lookup.stored?(@source_row)

    sheet = @lookup.sheet_for(@source_row)
    return :missing unless sheet

    @lookup.stage_part(sheet, part_attributes(sheet))
    return :attached if @batched

    @lookup.flush(returning: [ :id ]).rows.any? ? :attached : :skipped
  end

  private

  def part_attributes(sheet)
    template = @lookup.template_for(sheet)

    {
      part_reference: @source_row.part_number,
      phrase: @source_row.description,
      fingerprint: @source_row.fingerprint,
      brand: @source_row.manufacturer,
      item_group: @source_row.item_group,
      category: template&.category,
      vehicle_system: template&.vehicle_system,
      subsystem: template&.subsystem,
      product: template&.product,
      description: template&.description
    }
  end
end
