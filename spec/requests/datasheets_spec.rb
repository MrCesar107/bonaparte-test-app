require "rails_helper"

RSpec.describe "Datasheets", type: :request do
  describe "GET /datasheets/new" do
    it "renders a file upload for xlsx and csv files" do
      user = User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-datasheet-new@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      sign_in user

      get new_datasheet_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="datasheet_form"')
      expect(response.body).to include('id="new_datasheet"')
      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).to include('enctype="multipart/form-data"')
      expect(response.body).to include('name="file"')
      expect(response.body).to include('accept=".xlsx,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv"')
      expect(response.body).to include("border-dashed")
      expect(response.body).to include("Click or drag an .xlsx or .csv file here to upload it")
    end
  end
end
