require "test_helper"

class JobTest < ActiveSupport::TestCase
  test "enqueued jobs start queued" do
    job = Job.create!(name: "notify", payload: { action: "echo" }.to_json)
    assert_predicate job, :queued?
  end

  test "name is required" do
    assert_not Job.new(name: "").valid?
  end

  test "claim_next atomically hands out the oldest queued job" do
    first = Job.create!(name: "first", payload: { action: "echo" }.to_json)
    second = Job.create!(name: "second", payload: { action: "echo" }.to_json)

    claimed = Job.claim_next
    assert_equal first, claimed
    assert_predicate claimed, :processing?
    assert_equal 1, claimed.attempts
  end

  test "claim_next returns nil when nothing is queued" do
    assert_nil Job.claim_next
  end

  test "processing an echo job marks it done and stamps processed_at" do
    job = Job.create!(name: "echo", payload: { action: "echo", message: "hi" }.to_json)
    claimed = Job.claim_next
    claimed.process

    assert_predicate job.reload, :done?
    assert_not_nil job.reload.processed_at
  end

  test "unsupported or malformed payloads mark the job failed" do
    bad = Job.create!(name: "mystery", payload: { action: "unknown" }.to_json)
    bad.process
    assert_predicate bad.reload, :failed?
    assert_not_nil bad.reload.last_error

    broken = Job.create!(name: "broken", payload: "not json {")
    broken.process
    assert_predicate broken.reload, :failed?
    assert_includes broken.reload.last_error, "ParserError"
  end
end
