require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @task = Task.new(title: "Ship it", owner: "nobin", status: :todo, priority: :medium)
  end

  test "valid with required attributes" do
    assert @task.valid?
  end

  test "title is required" do
    @task.title = ""
    assert_not @task.valid?
    assert_includes @task.errors[:title], "can't be blank"
  end

  test "unknown enum values are rejected" do
    @task.status = :bogus
    assert_not @task.valid?
    assert_includes @task.errors[:status], "is not included in the list"

    @task = Task.new(title: "Ship it", owner: "nobin", status: :todo, priority: :medium)
    @task.priority = :bogus
    assert_not @task.valid?
    assert_includes @task.errors[:priority], "is not included in the list"
  end

  test "search matches title, description and owner" do
    login = Task.create!(title: "Fix login", description: "audit auth flows", owner: "nobin")
    docs = Task.create!(title: "Write docs", description: "document the login page", owner: "eve")
    Task.create!(title: "Other", owner: "zoe")

    assert_equal [ login, docs ].sort_by(&:id), Task.search("login").sort_by(&:id)
    assert_equal [ login ], Task.search("auth")
  end

  test "search escapes LIKE wildcards" do
    Task.create!(title: "100% coverage", owner: "nobin")
    assert_equal 0, Task.search("10%%").count
    assert_equal 1, Task.search("100%").count
  end

  test "status and priority scopes filter" do
    todo = Task.create!(title: "todo one", status: :todo, priority: :high)
    done = Task.create!(title: "done one", status: :done, priority: :low)

    assert_equal [ todo.id ], Task.by_status(:todo).pluck(:id)
    assert_equal [ done.id ], Task.by_status(:done).pluck(:id)
    assert_equal [ todo.id ], Task.by_priority(:high).pluck(:id)
  end

  test "overdue scope returns only incomplete future-past tasks" do
    overdue = Task.create!(title: "late", status: :todo, due_on: 1.day.ago)
    done_late = Task.create!(title: "finished late", status: :done, due_on: 2.days.ago)
    upcoming = Task.create!(title: "soon", status: :todo, due_on: 1.day.from_now)

    assert_equal [ overdue.id ], Task.overdue.pluck(:id)
    assert_not_includes Task.overdue.pluck(:id), done_late.id
    assert_not_includes Task.overdue.pluck(:id), upcoming.id
  end
end
