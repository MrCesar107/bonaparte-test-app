require "rails_helper"

RSpec.describe "Datasheet source rows", type: :request do
  describe "GET /datasheets/:datasheet_id/source_rows" do
    it "redirects to sign in when the user is not authenticated" do
      datasheet = create(:datasheet)

      get datasheet_source_rows_path(datasheet)

      expect(response).to redirect_to(new_user_session_path)
    end

    context "when signed in" do
      before { sign_in create(:user) }

      it "renders the source rows table inside the datasheet turbo frame" do
        datasheet = create(:datasheet)

        get datasheet_source_rows_path(datasheet)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(%(id="source_rows_#{datasheet.id}"))
        expect(response.body).to include("overflow-x-auto")
        expect(response.body).to include("Internal Code")
        expect(response.body).to include("Part Number")
        expect(response.body).to include("Article Description")
        expect(response.body).to include("Item Group")
        expect(response.body).to include("Manufacturer")
        expect(response.body).to include("Unit")
        expect(response.body).not_to include("<html")
      end

      it "renders that datasheet's rows and leaves other datasheets out" do
        datasheet = create(:datasheet)
        create(
          :source_row,
          datasheet: datasheet,
          internal_code: "RM-152",
          part_number: "DM-152",
          description: "bomba de aceite",
          article_description: "BOMBA DE ACEITE",
          item_group: "BOMBAS",
          manufacturer: "Rexite",
          unit: "PZA"
        )
        create(:source_row, internal_code: "OTHER-999")

        get datasheet_source_rows_path(datasheet)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("RM-152")
        expect(response.body).to include("DM-152")
        expect(response.body).to include("bomba de aceite")
        expect(response.body).to include("BOMBA DE ACEITE")
        expect(response.body).to include("BOMBAS")
        expect(response.body).to include("Rexite")
        expect(response.body).to include("PZA")
        expect(response.body).not_to include("OTHER-999")
      end

      it "renders the rows in position order" do
        datasheet = create(:datasheet)
        create(:source_row, datasheet: datasheet, position: 2, part_number: "SECOND")
        create(:source_row, datasheet: datasheet, position: 1, part_number: "FIRST")

        get datasheet_source_rows_path(datasheet)

        expect(response.body.index("FIRST")).to be < response.body.index("SECOND")
      end

      it "returns not found when the datasheet does not exist" do
        get datasheet_source_rows_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
