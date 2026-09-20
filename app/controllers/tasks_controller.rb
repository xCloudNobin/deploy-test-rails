class TasksController < ApplicationController
  before_action :set_task, only: %i[show edit update destroy]
  before_action :set_filters, only: :index

  def index
    @tasks = Task.order("priority DESC", "due_on ASC", "created_at DESC")
                 .then { |scope| @q.present? ? scope.search(@q) : scope }
                 .then { |scope| @status.present? ? scope.by_status(@status) : scope }
                 .then { |scope| @priority.present? ? scope.by_priority(@priority) : scope }
                 .then { |scope| @overdue ? scope.overdue : scope }
  end

  def show; end

  def new
    @task = Task.new
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      redirect_to task_path(@task), notice: "Task created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @task.update(task_params)
      redirect_to task_path(@task), notice: "Task updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_path, notice: "Task deleted."
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def set_filters
    @q = params[:q].to_s.strip
    @status = params[:status]
    @priority = params[:priority]
    @overdue = params[:overdue] == "1"
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :owner, :due_on)
  end
end
