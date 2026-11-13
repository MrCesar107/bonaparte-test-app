require "roo"

class Datasheet::Research::SpreadsheetReader
  def initialize(file)
    @file = file
  end

  def call
    spreadsheet = Roo::Spreadsheet.open(@file)

    spreadsheet
  end
end
