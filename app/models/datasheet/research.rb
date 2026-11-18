class Datasheet::Research
  LOOKUP_BATCH_SIZE = 250

  def initialize(
    datasheet,
    file,
    search: Datasheet::Research::SerpApiSearch.new,
    fetch: Datasheet::Research::PageFetch.new
  )
    @datasheet = datasheet
    @file = file
    @search = search
    @fetch = fetch
  end

  def call
    spreadsheet = ::Datasheet::Research::SpreadsheetReader.new(@file).call
    rows = build_source_rows_values(spreadsheet)
    @datasheet.with_lock(requires_new: true) do
      @datasheet.source_rows.delete_all
      @datasheet.source_rows.insert_all!(rows) if rows.any?
    end

    return @datasheet.failed! if rows.empty?

    research_source_rows ? @datasheet.failed! : @datasheet.created!
  rescue StandardError
    @datasheet.failed!
    raise
  end

  private

  def build_source_rows_values(spreadsheet)
    origin_rows_sheet = spreadsheet.sheet("Origen")

    origin_rows_sheet.each_row_streaming(offset: 1, pad_cells: true).filter_map do |row|
      build_source_info(row)
    end.each_with_index.map do |attributes, index|
      attributes.merge(position: index + 1)
    end
  end

  def research_source_rows
    failed = false
    part_store = @datasheet.part_store

    @datasheet.source_rows.reset.to_a.each_slice(LOOKUP_BATCH_SIZE) do |rows|
      lookup = Datasheet::Research::StoredRow::Lookup.new(part_store: part_store, source_rows: rows)
      rows.each do |source_row|
        stored = Datasheet::Research::StoredRow.new(part_store: part_store, source_row: source_row, lookup: lookup).call
        next unless stored == :missing

        lookup.flush
        phrase = lookup.phrase_for(source_row)
        result = Datasheet::Research::PageSearch.new(
          phrase: phrase, source_row: source_row, item_group: source_row.item_group,
          search: @search, fetch: @fetch
        ).call
        return true if result == :out_of_credits

        failed = true if result == :failed
        part = Datasheet::Research::SimileRecord.new(
          part_store: part_store, source_row: source_row, phrase: phrase, result: result
        ).call
        lookup.remember(part) if part
      end
      lookup.flush
    end

    failed
  end

  def build_source_info(row)
    cells = row.first(7).map { |cell| cell_text(cell) }
    return if cells.all?(&:blank?)

    {
      internal_code: cells[0],
      part_number: cells[1],
      article_description: cells[2],
      description: cells[3],
      item_group: cells[4],
      manufacturer: cells[5],
      unit: cells[6]
    }
  end

  def cell_text(cell)
    value = cell&.value
    return if value.blank?

    return whole_number(value) if value.is_a?(Numeric)

    value.to_s
  end

  def whole_number(value)
    number = value.to_f
    return number.to_i.to_s if number == number.to_i

    value.to_s
  end
end
