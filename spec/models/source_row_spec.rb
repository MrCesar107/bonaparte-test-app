require "rails_helper"

RSpec.describe SourceRow, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:datasheet) }
  end

  describe "validations" do
    subject { create(:source_row) }

    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:position).scoped_to(:datasheet_id) }
  end
end
