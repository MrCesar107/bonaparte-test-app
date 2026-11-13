require "rails_helper"

RSpec.describe Datasheet::Research::SpreadsheetReader do
  it "opens the workbook and exposes its sheets" do
    File.open(file_fixture("origin.xlsx"), "rb") do |file|
      spreadsheet = described_class.new(file).call

      expect(spreadsheet.sheets).to eq([ "Origen", "Métricas" ])
    end
  end
end
