require "rails_helper"

RSpec.describe "Part stores", type: :request do
  before { sign_in create(:user) }

  describe "GET /part_stores/new" do
    it "renders the new part store form" do
      get new_part_store_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="part_store_form"')
      expect(response.body).to include(%(action="#{part_stores_path}"))
      expect(response.body).to include('name="part_store[name]"')
      expect(response.body).to include("Enter the part store name")
      expect(response.body).to include("Create Part Store")
      expect(response.body).not_to include('data-turbo-frame="_top"')
    end
  end

  describe "POST /part_stores" do
    it "renders the new form with errors when the part store cannot be created" do
      expect {
        post part_stores_path, params: { part_store: { name: "" } }, headers: { "Turbo-Frame" => "part_store_form" }
      }.not_to change(PartStore, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('id="part_store_form"')
      expect(response.body).to include("Check the information below:")
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).to include("text-red-600")
      expect(response.body).to include('name="part_store[name]"')
    end

    it "redirects to the part store when it is created" do
      expect {
        post part_stores_path, params: { part_store: { name: "North Garage" } }
      }.to change(PartStore, :count).by(1)

      part_store = PartStore.find_by!(name: "North Garage")
      expect(response).to redirect_to(part_store_path(part_store))
      follow_redirect!

      expect(response.body).to include("North Garage")
      expect(response.body).to include("Part store created successfully")
      expect(response.body).to include('data-controller="alert"')
    end
  end

  describe "GET /part_stores/:id" do
    it "renders the part store with the application layout" do
      part_store = create(:part_store, name: "North Garage")

      get part_store_path(part_store)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("North Garage")
      expect(response.body).to include("Logout")
    end

    it "lists the part store datasheets with the newest first" do
      part_store = create(:part_store, name: "North Garage")
      other_store = create(:part_store, name: "South Garage")
      older = create(:datasheet, part_store: part_store)
      newer = create(:datasheet, part_store: part_store)
      other = create(:datasheet, part_store: other_store)
      older.update_columns(name: "older-sheet", created_at: 2.days.ago)
      newer.update_columns(name: "newer-sheet", created_at: 1.hour.ago)
      other.update_columns(name: "other-sheet")

      get part_store_path(part_store)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("newer-sheet")
      expect(response.body).to include(%(id="datasheet_#{newer.id}"))
      expect(response.body).to include("older-sheet")
      expect(response.body).to include("Procesando")
      expect(response.body).to include('data-controller="datasheet-status"')
      expect(response.body).not_to include("other-sheet")
      expect(response.body).not_to include("fa-chevron-right")
      expect(response.body).not_to include("Origen")
      expect(response.body.index("newer-sheet")).to be < response.body.index("older-sheet")
    end

    it "shows a chevron that toggles the sections once the datasheet is ready" do
      part_store = create(:part_store, name: "North Garage")
      datasheet = create(:datasheet, part_store: part_store, status: :created)
      datasheet.update_columns(name: "ready-sheet")

      get part_store_path(part_store)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ready-sheet")
      expect(response.body).to include("fa-chevron-right")
      expect(response.body).to include('data-controller="datasheet-card"')
      expect(response.body).to include('data-open="false"')
      expect(response.body).to include('data-action="datasheet-card#toggle"')
      expect(response.body).to include("transition-[height]")
      expect(response.body).to include("group-data-[open=true]:rotate-90")
      expect(response.body).to include(%(class="block w-full min-w-0 overflow-x-auto" id="source_rows_#{datasheet.id}" src="#{datasheet_source_rows_path(datasheet)}"))
      expect(response.body).to include("Origen")
      expect(response.body).to include("Métricas")
      expect(response.body).to include("Aplicaciones")
      expect(response.body).to include("Intercambios")
      expect(response.body).to include("Atributos")
      expect(response.body).to include("Catálogo")
      expect(response.body).not_to include("Procesando")
      expect(response.body).not_to include("datasheet-status")
    end

    it "leaves researched similars off the catalog list" do
      part_store = create(:part_store, name: "North Garage")
      upload = create(:datasheet, part_store: part_store)
      simile = create(:datasheet, part_store: part_store, equivalent: "DM-152", status: :created, url: "https://parts.test/dm-152")
      upload.update_columns(name: "upload-sheet")
      simile.update_columns(name: "simile-sheet")

      get part_store_path(part_store)

      expect(response.body).to include("upload-sheet")
      expect(response.body).not_to include("simile-sheet")
    end
  end
end
