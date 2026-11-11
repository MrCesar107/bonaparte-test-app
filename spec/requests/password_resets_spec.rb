require "rails_helper"

RSpec.describe "Password reset", type: :request do
  describe "GET /users/password/new" do
    it "uses the same card as the other Devise screens" do
      get new_user_password_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forgot your password?")
      expect(response.body).to include("Enter your email")
      expect(response.body).to include("Send me password reset instructions")
      expect(response.body).to include(new_user_session_path)
      expect(response.body).to include(new_user_registration_path)
    end
  end
end
