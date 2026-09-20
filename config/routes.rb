Rails.application.routes.draw do
  # Health endpoints used by load balancers / orchestrators.
  get "up" => "rails/health#show", as: :rails_health_check
  get "health/live" => "health#live"
  get "health/ready" => "health#ready"
  get "health/release" => "health#release"

  # Authentication.
  resource :session, only: %i[new create destroy]

  # Taskboard.
  resources :tasks

  root "tasks#index"
end
