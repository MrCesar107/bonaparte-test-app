require "rails_helper"

RSpec.describe Datasheet::Research do
  it "replaces the datasheet source rows with the Origen sheet and marks it created" do
    datasheet = create(:datasheet)
    create(:source_row, datasheet: datasheet, part_number: "OLD-1")
    create(:source_row, part_number: "KEEP-ME")

    File.open(file_fixture("origin.xlsx"), "rb") do |file|
      described_class.new(datasheet, file).call
    end

    rows = datasheet.source_rows

    expect(datasheet.reload).to be_created
    expect(rows.map(&:position)).to eq([ 1, 2 ])
    expect(rows.map(&:part_number)).to eq([ "DM-152", "X-200" ])
    expect(rows.first).to have_attributes(
      internal_code: "RM-152",
      part_number: "DM-152",
      description: "Nissan Tsuru bomba",
      article_description: "BOMBA DE ACEITE",
      item_group: "BOMBAS",
      manufacturer: "Rexite",
      unit: "PZA",
      position: 1,
      datasheet_id: datasheet.id
    )
    expect(rows.second).to have_attributes(
      internal_code: "RM-200",
      position: 2,
      description: nil,
      article_description: "FILTRO",
      item_group: "FILTROS",
      manufacturer: "Hastings",
      unit: nil
    )
    expect(SourceRow.where(part_number: "OLD-1")).to be_empty
    expect(SourceRow.where(part_number: "KEEP-ME")).to exist
  end

  it "marks the datasheet failed when Origen has no data rows" do
    datasheet = create(:datasheet)

    File.open(file_fixture("origin_header.xlsx"), "rb") do |file|
      described_class.new(datasheet, file).call
    end

    expect(datasheet.reload).to be_failed
    expect(datasheet.source_rows).to be_empty
  end

  it "leaves the datasheet pending when the workbook has no Origen sheet" do
    datasheet = create(:datasheet)

    expect {
      File.open(file_fixture("missing_origin.xlsx"), "rb") do |file|
        described_class.new(datasheet, file).call
      end
    }.to raise_error(RangeError, "sheet 'Origen' not found")

    expect(datasheet.reload).to be_pending
  end
end
