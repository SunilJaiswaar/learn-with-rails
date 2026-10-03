# Signs a user in through the real session flow, so request specs exercise the
# same cookie and Session record that production uses.
module AuthenticationHelpers
  def sign_in_as(user, password: "password-for-specs")
    post login_path, params: { email: user.email, password: password }
    expect(response).to have_http_status(:found)
    user
  end
end
