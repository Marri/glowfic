class Api::ApiController < ActionController::Base
  include Rails::Pagination
  include Authentication::Api

  protect_from_forgery with: :null_session
  before_action :check_token
  around_action :set_timezone
  around_action :handle_param_validation

  resource_description do
    formats ['json']
    meta author: {name: 'Marri'}
    app_info 'The public API for the Glowfic Constellation'
  end

  protected

  def check_token
    # checks for invalid tokens in a before to prevent double renders
    logged_in?
  end

  def login_required
    return if logged_in?
    error = {message: "You must be logged in to view that page."}
    render json: {errors: [error]}, status: :unauthorized and return
  end

  def set_timezone
    Time.use_zone("UTC") { yield }
  end

  def handle_param_validation
    yield
  rescue Apipie::ParamMissing, Apipie::ParamInvalid => e
    error_hash = {message: Glowfic::Sanitizers.full(e.message.tr('"', "'"))}
    render json: {errors: [error_hash]}, status: :unprocessable_entity
  end

  def access_denied
    error = {message: "You do not have permission to perform this action."}
    render json: {errors: [error]}, status: :forbidden
  end

  def find_object(klass, param: :id, status: :not_found)
    object = klass.find_by_id(params[param])
    unless object
      error = {message: klass.to_s + " could not be found."}
      render json: {errors: [error]}, status: status and return
    end
    object
  end

  def per_page
    per = params[:per_page].to_i
    return 25 if per < 1
    return 100 if per > 100
    per
  end
end
