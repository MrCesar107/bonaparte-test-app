require "rails_helper"

RSpec.describe Datasheet, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:part_store) }
    it { is_expected.to have_many(:source_rows).dependent(:destroy) }
    it { is_expected.to have_one_attached(:file) }
  end

  describe "enums" do
    it do
      is_expected.to define_enum_for(:status).with_values(
        pending: "pending",
        created: "created",
        not_found: "not_found",
        failed: "failed"
      ).backed_by_column_of_type(:string)
    end
  end

  describe "validations" do
    it { is_expected.to allow_value(nil).for(:equivalent) }
    it { is_expected.to allow_value(nil).for(:url) }
  end

  it "defaults status to pending" do
    expect(create(:datasheet)).to be_pending
  end

  it "assigns a name from the creation timestamp" do
    created_at = Time.zone.local(2026, 3, 4, 5, 6, 7)
    datasheet = create(:datasheet, created_at: created_at, updated_at: created_at)

    expect(datasheet.reload.name).to eq("datasheet_20260304050607")
  end
end
