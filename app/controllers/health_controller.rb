class HealthController < ApplicationController
  skip_before_action :require_login

  def live
    render json: { status: "ok" }
  end

  def ready
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok", db: "up", release: release_version }
  rescue ActiveRecord::ActiveRecordError => e
    render json: { status: "error", db: "down", release: release_version, message: e.message },
           status: :service_unavailable
  end

  def release
    render json: { release: release_version }
  end

  private

  def release_version
    ENV.fetch("RELEASE_VERSION", nil) || default_release
  end

  def default_release
    Rails.root.join("RELEASE").read.strip
  rescue Errno::ENOENT
    "dev"
  end
end
