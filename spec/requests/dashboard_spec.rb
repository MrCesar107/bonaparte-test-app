require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    it "opens the new part store form inside the modal" do
      sign_in create(:user)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="modal"')
      expect(response.body).to include('data-action="modal#open"')
      expect(response.body).to include("New Part Store")
      expect(response.body).to include(%(href="#{new_part_store_path}"))
      expect(response.body).to include('id="part_store_form"')
      expect(response.body).to include('data-turbo-frame="part_store_form"')
    end
  end
end
