require "rails_helper"

RSpec.describe "Datasheets", type: :request do
  describe "GET /datasheets/new" do
    it "renders a file upload for xlsx and csv files" do
      sign_in create(:user)

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

  describe "POST /datasheets" do
    let(:user) { create(:user) }
    let(:part_store) { create(:part_store) }

    before { sign_in user }

    it "creates a pending datasheet and redirects with a notice when a file is uploaded" do
      upload = uploaded_csv

      expect {
        post datasheets_path, params: { part_store_id: part_store.id, file: upload }
      }.to change(part_store.datasheets, :count).by(1)

      datasheet = part_store.datasheets.last
      expect(datasheet.status).to eq("pending")
      expect(datasheet.name).to eq("datasheet_#{datasheet.created_at.strftime("%Y%m%d%H%M%S")}")
      expect(datasheet.file).to be_attached
      expect(DatasheetResearchJob).to have_been_enqueued.with(datasheet)
      expect(response).to redirect_to(part_store_path(part_store))

      follow_redirect!
      expect(response.body).to include("File was uploaded successfully")
      expect(response.body).to include(datasheet.name)
    end

    it "creates the datasheet and redirects with an alert when the file is missing" do
      expect {
        post datasheets_path, params: { part_store_id: part_store.id }
      }.to change(part_store.datasheets, :count).by(1)

      expect(response).to redirect_to(part_store_path(part_store))

      follow_redirect!
      expect(response.body).to include("An error occurred while uploading the file. Please try again.")
    end

    it "returns not found when the part store does not exist" do
      expect {
        post datasheets_path, params: { part_store_id: 0, file: uploaded_csv }
      }.not_to change(Datasheet, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /datasheets/:id" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "renders a processing frame without the chevron or sections" do
      datasheet = create(:datasheet, status: :pending)
      datasheet.update_columns(name: "pending-sheet")

      get datasheet_path(datasheet)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="datasheet_#{datasheet.id}"))
      expect(response.body).to include("pending-sheet")
      expect(response.body).to include("Procesando")
      expect(response.body).to include('data-controller="datasheet-status"')
      expect(response.body).to include(%(data-datasheet-status-url-value="#{datasheet_path(datasheet)}"))
      expect(response.body).not_to include("fa-chevron-right")
      expect(response.body).not_to include("Origen")
      expect(response.body).not_to include('src="')
    end

    it "renders the chevron and collapsed sections when the datasheet is ready" do
      datasheet = create(:datasheet, status: :created)
      datasheet.update_columns(name: "ready-sheet")

      get datasheet_path(datasheet)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ready-sheet")
      expect(response.body).to include("fa-chevron-right")
      expect(response.body).to include('data-action="datasheet-card#toggle"')
      expect(response.body).to include('data-open="false"')
      expect(response.body).to include("transition-[height]")
      expect(response.body).to include("group-data-[open=true]:rotate-90")
      expect(response.body).to include("Origen")
      expect(response.body).not_to include("Procesando")
      expect(response.body).not_to include("datasheet-status")
    end

    it "renders a finished message without sections when processing fails" do
      datasheet = create(:datasheet, status: :failed)
      datasheet.update_columns(name: "failed-sheet")

      get datasheet_path(datasheet)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("failed-sheet")
      expect(response.body).to include("No se pudo procesar")
      expect(response.body).not_to include("fa-chevron-right")
      expect(response.body).not_to include("datasheet-status")
      expect(response.body).not_to include("Origen")
    end
  end

  def uploaded_csv
    file = Tempfile.new([ "catalog", ".csv" ])
    file.write("equivalent,url\n")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  end
end
