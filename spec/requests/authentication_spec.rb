require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let!(:user) { create(:user, email: "learner@example.com") }

  describe "signing in" do
    it "starts a session with valid credentials" do
      post login_path, params: { email: user.email, password: "password-for-specs" }

      expect(response).to redirect_to(dashboard_path)
      expect(user.sessions.count).to eq(1)
    end

    it "rejects a wrong password" do
      post login_path, params: { email: user.email, password: "wrong" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.sessions).to be_empty
    end

    it "gives the same message for an unknown email as for a wrong password" do
      post login_path, params: { email: "nobody@example.com", password: "wrong" }
      unknown = response.body[/That email and password[^<]*/]

      post login_path, params: { email: user.email, password: "wrong" }
      wrong = response.body[/That email and password[^<]*/]

      # The form must not reveal which addresses exist.
      expect(unknown).to eq(wrong)
      expect(unknown).to be_present
    end

    it "locks the account after repeated failures" do
      User::MAX_FAILED_LOGINS.times do
        post login_path, params: { email: user.email, password: "wrong" }
      end

      expect(user.reload).to be_locked

      post login_path, params: { email: user.email, password: "password-for-specs" }

      expect(response).to redirect_to(login_path)
      expect(user.sessions).to be_empty
    end

    it "clears the failure count after a successful sign-in" do
      post login_path, params: { email: user.email, password: "wrong" }
      post login_path, params: { email: user.email, password: "password-for-specs" }

      expect(user.reload.failed_login_count).to eq(0)
    end
  end

  describe "signing out" do
    it "destroys the session record so the cookie cannot be replayed" do
      sign_in_as(user)
      expect(user.sessions.count).to eq(1)

      delete logout_path

      expect(user.sessions).to be_empty
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "protected pages" do
    it "redirects an anonymous visitor to sign in" do
      get dashboard_path

      expect(response).to redirect_to(login_path)
    end

    it "returns the visitor to where they were heading" do
      get challenges_path
      sign_in_as(user)

      expect(response).to redirect_to(challenges_path)
    end

    it "rejects an expired session" do
      sign_in_as(user)
      user.sessions.update_all(expires_at: 1.hour.ago)

      get dashboard_path

      expect(response).to redirect_to(login_path)
    end
  end

  describe "registration" do
    it "creates a learner and signs them in" do
      expect {
        post signup_path, params: {
          user: { name: "New Person", email: "new@example.com",
                  password: "a-long-enough-password",
                  password_confirmation: "a-long-enough-password",
                  experience_band: "junior", timezone: "UTC" }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(dashboard_path)
      expect(User.last.role).to eq("learner")
    end

    it "ignores an attempt to self-assign the admin role" do
      post signup_path, params: {
        user: { name: "Sneaky", email: "sneaky@example.com",
                password: "a-long-enough-password",
                password_confirmation: "a-long-enough-password",
                role: "admin", experience_band: "junior", timezone: "UTC" }
      }

      expect(User.find_by(email: "sneaky@example.com").role).to eq("learner")
    end

    it "rejects a short password" do
      expect {
        post signup_path, params: {
          user: { name: "Short", email: "short@example.com",
                  password: "tiny", password_confirmation: "tiny",
                  experience_band: "junior", timezone: "UTC" }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses registration when the admin has closed it" do
      AppSetting.set!("registration_open", false)

      expect {
        post signup_path, params: {
          user: { name: "Late", email: "late@example.com",
                  password: "a-long-enough-password",
                  password_confirmation: "a-long-enough-password",
                  experience_band: "junior", timezone: "UTC" }
        }
      }.not_to change(User, :count)
    ensure
      AppSetting.set!("registration_open", true)
    end
  end
end
