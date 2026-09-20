require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "nobin@example.com", password: "password123")
    @task = Task.create!(title: "Fix login", owner: "nobin", status: :todo, priority: :high)
  end

  test "requires login" do
    get tasks_path
    assert_redirected_to new_session_path

    get new_task_path
    assert_redirected_to new_session_path
  end

  test "index lists tasks once signed in" do
    sign_in_as
    get tasks_path
    assert_response :success
    assert_match @task.title, response.body
  end

  test "index filters and searches" do
    sign_in_as
    done = Task.create!(title: "Done thing", status: :done, priority: :low, owner: "eve")

    get tasks_path, params: { q: "login" }
    assert_response :success
    assert_match @task.title, response.body
    assert_no_match done.title, response.body

    get tasks_path, params: { status: "done" }
    assert_match done.title, response.body
    assert_no_match @task.title, response.body

    get tasks_path, params: { priority: "high" }
    assert_match @task.title, response.body
    assert_no_match done.title, response.body

    get tasks_path, params: { overdue: "1" }
    assert_response :success
  end

  test "show displays a task" do
    sign_in_as
    get task_path(@task)
    assert_response :success
    assert_match @task.title, response.body
  end

  test "create persists a valid task" do
    sign_in_as
    assert_difference "Task.count", 1 do
      post tasks_path, params: { task: { title: "New task", owner: "nobin", status: "in_progress", priority: "low" } }
    end
    assert_redirected_to task_path(Task.last)
  end

  test "create rejects an invalid task" do
    sign_in_as
    assert_no_difference "Task.count" do
      post tasks_path, params: { task: { title: "", owner: "nobin" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors li", "Title can't be blank"
  end

  test "update modifies the task" do
    sign_in_as
    patch task_path(@task), params: { task: { title: "Fixed login", status: "done" } }

    assert_redirected_to task_path(@task)
    assert_equal "Fixed login", @task.reload.title
    assert_predicate @task.reload, :done?
  end

  test "destroy removes the task" do
    sign_in_as
    assert_difference "Task.count", -1 do
      delete task_path(@task)
    end
    assert_redirected_to tasks_path
  end

  private

  def sign_in_as
    post session_path, params: { session: { email: @user.email, password: "password123" } }
    assert_redirected_to tasks_path
  end
end
