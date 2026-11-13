require "rails_helper"

RSpec.describe DatasheetResearchJob, type: :job do
  it "reads the attached file and removes it afterwards" do
    datasheet = datasheet_with_file
    research = instance_double(Datasheet::Research, call: true)

    expect(Datasheet::Research).to receive(:new).with(datasheet, kind_of(Tempfile)) { research }

    described_class.perform_now(datasheet)

    expect(datasheet.reload.file).not_to be_attached
  end

  it "keeps the file attached when research raises" do
    datasheet = datasheet_with_file
    allow(Datasheet::Research).to receive(:new).and_raise(RuntimeError, "unreadable")

    expect {
      described_class.perform_now(datasheet)
    }.to raise_error(RuntimeError, "unreadable")

    expect(datasheet.reload.file).to be_attached
  end

  def datasheet_with_file
    create(:datasheet).tap do |datasheet|
      datasheet.file.attach(
        io: StringIO.new("equivalent,url\n"),
        filename: "catalog.csv",
        content_type: "text/csv"
      )
    end
  end
end
