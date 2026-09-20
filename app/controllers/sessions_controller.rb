class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    credentials = params[:session]
    user = User.find_by(email: credentials[:email].to_s.strip.downcase)
    if user&.authenticate(credentials[:password])
      session[:user_id] = user.id
      redirect_to tasks_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Signed out."
  end
end
