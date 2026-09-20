if Rails.env.production? && ENV.fetch("ALLOW_DEMO_SEED", "false") != "true"
  warn "seeds.rb: refusing to seed demo data in production unless ALLOW_DEMO_SEED=true"
  exit 1
end

user = User.find_or_initialize_by(email: "demo@example.com")
user.password = ENV.fetch("DEMO_PASSWORD", "password")
user.save!

%w[Alpha Bravo Charlie].each_with_index do |name, i|
  Task.find_or_create_by!(title: "#{name} task") do |task|
    task.description = "A sample #{name.downcase} task to try out the board."
    task.owner = user.email
    task.status = %w[todo in_progress done][i % 3]
    task.priority = %w[low medium high][i % 3]
    task.due_on = i.zero? ? 2.days.from_now.to_date : nil
  end
end

Job.find_or_create_by!(name: "demo-welcome") do |job|
  job.payload = JSON.generate(action: "echo", message: "Welcome to the Taskboard worker.")
end

puts "Seeded: #{user.email} / #{user.password} (+ #{Task.count} tasks, #{Job.count} queued job)"
