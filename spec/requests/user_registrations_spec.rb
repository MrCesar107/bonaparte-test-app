require "rails_helper"

RSpec.describe "User registration", type: :request do
  describe "GET /users/sign_up" do
    it "shows a reusable hint beside the password label" do
      get new_user_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Password")
      expect(response.body).to include('data-controller="hint"')
      expect(response.body).to include("fa-question-circle")
      expect(response.body).to include("6 characters minimum")
      expect(response.body).to include("Log in")
      expect(response.body).to include(new_user_session_path)
      expect(response.body).not_to include('class="hint"')
    end
  end
end
