class Datasheet::Research
  def initialize(datasheet, file)
    @datasheet = datasheet
    @file = file
  end

  def call
    spreadsheet = ::Datasheet::Research::SpreadsheetReader.new(@file).call
    rows = build_source_rows_values(spreadsheet)
    @datasheet.source_rows.destroy_all

    return @datasheet.failed! if rows.empty?

    @datasheet.source_rows.insert_all(rows)
    @datasheet.created!
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

  def build_source_info(row)
    cells = row.first(7).map { |cell| cell&.value }
    return if cells.all?(&:blank?)

    {
      internal_code: cells[0],
      part_number: cells[1],
      description: cells[2],
      article_description: cells[3],
      item_group: cells[4],
      manufacturer: cells[5],
      unit: cells[6]
    }
  end
end
