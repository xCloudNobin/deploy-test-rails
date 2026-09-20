class Task < ApplicationRecord
  STATUSES = { todo: 0, in_progress: 1, done: 2 }.freeze
  PRIORITIES = { low: 0, medium: 1, high: 2 }.freeze

  enum :status, STATUSES, validate: true
  enum :priority, PRIORITIES, validate: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :owner, length: { maximum: 100 }

  scope :by_status, ->(status) { status.present? ? where(status: status) : all }
  scope :by_priority, ->(priority) { priority.present? ? where(priority: priority) : all }
  scope :overdue, -> { todo.where("due_on < ?", Time.zone.today) }
  scope :search, ->(q) {
    next all if q.blank?

    term = "%#{sanitize_sql_like(q)}%"
    escape = "\\"
    where(
      "tasks.title LIKE :q ESCAPE :e OR tasks.description LIKE :q ESCAPE :e OR tasks.owner LIKE :q ESCAPE :e",
      q: term, e: escape
    )
  }
  scope :ordered, -> { order(priority: :desc, due_on: :asc, created_at: :desc) }
end
