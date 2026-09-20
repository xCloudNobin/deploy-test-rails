require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "nobin@example.com", password: "password123")
  end

  # Rails disables forgery protection in the test environment by default.
  # Toggle it on for these two tests to prove the app's protect_from_forgery
  # middleware actually blocks forged requests and accepts the real token.
  teardown do
    ActionController::Base.allow_forgery_protection = false
  end

  test "a POST without a CSRF token is rejected" do
    ActionController::Base.allow_forgery_protection = true

    post session_path, params: { session: { email: @user.email, password: "password123" } }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "a POST carrying the CSRF token succeeds" do
    ActionController::Base.allow_forgery_protection = true

    get new_session_path
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    assert token.present?, "expected an authenticity token in the login form"

    post session_path, params: { session: { email: @user.email, password: "password123" } },
                       headers: { "X-CSRF-Token" => token }

    assert_redirected_to tasks_path
    assert_equal @user.id, session[:user_id]
  end
end
