require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "nobin@example.com", password: "password123")
  end

  test "new renders the login page" do
    get new_session_path
    assert_response :success
  end

  test "create signs in with valid credentials" do
    post session_path, params: { session: { email: @user.email, password: "password123" } }
    assert_redirected_to tasks_path
    assert_equal @user.id, session[:user_id]
  end

  test "create rejects invalid credentials" do
    post session_path, params: { session: { email: @user.email, password: "wrong" } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "destroy signs the user out" do
    post session_path, params: { session: { email: @user.email, password: "password123" } }
    delete session_path

    assert_redirected_to new_session_path
    assert_nil session[:user_id]
  end
end
