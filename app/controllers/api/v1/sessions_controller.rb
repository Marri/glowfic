class Api::V1::SessionsController < Api::ApiController
  before_action :logout_required

  def create
    auth = Authentication.new
    unless auth.authenticate(params[:username], params[:password])
      error = {message: auth.error}
      render json: {errors: [error]}, status: :unauthorized and return
    end

    render json: {token: auth.api_token}
  end

  private

  def logout_required
    return unless logged_in?
    error = {message: "You must be logged out to call this endpoint."}
    render json: {errors: [error]}, status: :unauthorized and return
  end
end
