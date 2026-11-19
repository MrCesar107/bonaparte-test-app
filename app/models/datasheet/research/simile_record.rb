# It saves an equivalent part's research result and links the store's part to that datasheet.

# Writes the outcome, fitments, interchanges, specifications, and part in one transaction.

# Reuses a completed datasheet when the store has already researched the equivalent.

# Uses Part's attribute policy and preserves missing or failed results so later
# input rows can recognize research that has already been attempted.
class Datasheet::Research::SimileRecord
  def initialize(part_store:, source_row:, phrase:, result:)
    @part_store = part_store
    @source_row = source_row
    @phrase = phrase
    @result = result
  end

  # Persists the search's completed extraction without parsing or transcribing again.
  # Reuses finished research and skips conflicting part fingerprints.
  def call
    return if equivalent.blank?

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
    return @result.url if hit? && !@result.extraction.unavailable?

    ""
  end

  def status
    return :failed if hit? && @result.extraction.unavailable?
    return :created if publishable?
    return :not_found if @result == :not_found || hit?

    :failed
  end

  def publishable?
    hit? && @result.extraction.accepted?
  end

  def hit?
    @result.is_a?(Datasheet::Research::PageSearch::Hit)
  end

  def lists
    hit? ? @result.extraction.lists : Datasheet::Research::PageLists::Lists.empty
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
    insert_part(sheet, **Part.attributes_for_source(source_row: @source_row, template: template))
  end

  def attach_new_part(sheet, read)
    insert_part(sheet, **Part.attributes_for_research(source_row: @source_row, lists: read))
  end

  def insert_part(sheet, **attributes)
    row = attributes.merge(datasheet_id: sheet.id, part_store_id: sheet.part_store_id)
    inserted = Part.insert_fingerprinted([ row ], returning: Part.column_names).first
    return unless inserted

    Part.instantiate(inserted).tap { |part| part.datasheet = sheet }
  end
end
