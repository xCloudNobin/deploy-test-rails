# Puma can serve each request in a thread from an internal thread pool.
# The `workers` method takes a number as an argument (puma can spawn multiple
# worker processes), and `threads` takes a start and end count.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3).to_i
threads threads_count, threads_count

# Bind to a Unix socket or TCP port, configurable via environment.
port ENV.fetch("PORT", 3000)
bind "unix://#{ENV.fetch("UNIX_SOCKET", "")}" if ENV["UNIX_SOCKET"].present?

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV", "development")

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Deploy with multiple processes: set WEB_CONCURRENCY > 1 in production.
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i

# Use the `preload_app!` method when running multiple workers; it boots the
# application once and forks, which is faster than booting each worker.
preload_app! if ENV.fetch("WEB_CONCURRENCY", "0").to_i > 1

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Allow puma to gracefully restart when `RAILS_MAX_WORKERS` capability changes
# on the container orchestrator.
plugin :systemd if ENV["SYSTEMD"].present?

# Run as a daemon when a directory is given.
if ENV["DAEMONIZE"].present?
  daemonize true
  directory ENV.fetch("APP_DIR", Dir.pwd)
end

# Make sure Puma reads the env that dotenv/process managers set.
on_worker_boot do
  # DB connections established before fork are not shared reliably; touch the
  # pool so a fresh one is created per worker.
  ActiveRecord::Base.connection_handler.verify_active_connections! if defined?(ActiveRecord)
end
