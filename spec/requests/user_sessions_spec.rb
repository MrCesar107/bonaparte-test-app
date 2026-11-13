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
      expect(response.body).not_to include('data-controller="alert"')
    end
  end

  describe "POST /users/sign_in" do
    it "shows the controller notice in the alert component" do
      user = create(:user)

      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(response).to redirect_to(root_path)
      follow_redirect!

      expect(response.body).to include("Signed in successfully.")
      expect(response.body).to include('data-controller="alert"')
      expect(response.body).to include('data-action="alert#close"')
      expect(response.body).to include("bg-emerald-50")
    end
  end
end