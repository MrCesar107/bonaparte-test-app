require "rails_helper"

RSpec.describe PartStore, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:datasheets).dependent(:destroy) }
  end

  it "destroys its datasheets and their source rows" do
    part_store = create(:part_store)
    datasheet = create(:datasheet, part_store: part_store)
    create(:source_row, datasheet: datasheet)

    expect { part_store.destroy }
      .to change(Datasheet, :count).by(-1)
      .and change(SourceRow, :count).by(-1)
  end
end
