require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is required and must be unique" do
    User.create!(email: "nobin@example.com", password: "password123")

    dup = User.new(email: "NOBIN@example.com", password: "password123")
    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"

    blank = User.new(email: "", password: "password123")
    assert_not blank.valid?

    malformed = User.new(email: "not-an-email", password: "password123")
    assert_not malformed.valid?
  end

  test "email is normalized before save" do
    user = User.create!(email: "  MiXeD@Example.COM ", password: "password123")
    assert_equal "mixed@example.com", user.email
  end

  test "authenticate accepts the right password and rejects the wrong one" do
    user = User.create!(email: "nobin@example.com", password: "password123")

    assert user.authenticate("password123")
    assert_not user.authenticate("nope")
  end

  test "password confirmation is enforced" do
    user = User.new(email: "nobin@example.com", password: "password123", password_confirmation: "different")
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end
end
