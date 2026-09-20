class Job < ApplicationRecord
  STATUSES = { queued: 0, processing: 1, done: 2, failed: 3 }.freeze

  enum :status, STATUSES, validate: true

  validates :name, presence: true, length: { maximum: 100 }

  scope :pending, -> { queued.order(:id) }
  scope :ordered, -> { order(:id) }

  # Atomically claims the next queued job and marks it as processing.
  def self.claim_next
    transaction do
      job = pending.lock.first
      job&.update!(status: :processing, attempts: job.attempts + 1)
      job
    end
  end

  # Carries out the job and persists the outcome. The payload is a small JSON
  # document describing the unit of work (see bin/worker for the worker loop).
  def process
    data = JSON.parse(payload.presence || "{}")

    case data["action"]
    when "echo"
      Rails.logger.info("[job #{id}] #{name}: #{data["message"]}")
      update!(status: :done, processed_at: Time.current)
    else
      raise ArgumentError, "unsupported job action: #{data["action"].inspect}"
    end
  rescue JSON::ParserError, ArgumentError => e
    update!(status: :failed, last_error: "#{e.class}: #{e.message}".truncate(255), processed_at: Time.current)
  end
end
