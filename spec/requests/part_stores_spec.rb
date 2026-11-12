require "rails_helper"

RSpec.describe "Part stores", type: :request do
  describe "GET /part_stores/new" do
    it "renders the new part store form" do
      user = User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-part-store-new@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      sign_in user

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
      user = User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-part-store@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      sign_in user

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
      user = User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-created@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      sign_in user

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
      user = User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-part-store-show@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      sign_in user
      part_store = PartStore.create!(name: "North Garage")

      get part_store_path(part_store)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("North Garage")
      expect(response.body).to include("Logout")
    end
  end
end
