require "rails_helper"

RSpec.describe "User session", type: :request do
  describe "GET /users/sign_in" do
    it "uses the same sign-in card without a password hint" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log in")
      expect(response.body).to include("Password")
      expect(response.body).not_to include('data-controller="hint"')
      expect(response.body).not_to include("6 characters minimum")
      expect(response.body).to include("Remember me")
    end
  end
end