require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "liveness does not require a session" do
    get health_live_path
    assert_response :success
    assert_equal({ "status" => "ok" }, JSON.parse(response.body))
  end

  test "readiness reports the database as up" do
    get health_ready_path
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ok", body["status"]
    assert_equal "up", body["db"]
  end

  test "release endpoint exposes the RELEASE marker" do
    get health_release_path
    assert_response :success
    assert_equal "0.1.0", JSON.parse(response.body)["release"]
  end
end
