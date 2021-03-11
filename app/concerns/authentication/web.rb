module Authentication::Web
  extend ActiveSupport::Concern

  included do
    protected

    def check_permanent_user
      return if logged_in?
      return unless cookies.signed[:user_id].present?

      session[:user_id] = cookies.signed[:user_id]
      set_user
    end

    def logged_in?
      current_user.present?
    end
    helper_method :logged_in?

    def current_user
      return unless session[:user_id].present?
      set_user
      return @current_user if @current_user
      logout # the user id stored in session does not exist, probably due to staging db reset
    end
    helper_method :current_user

    def logout
      reset_session
      cookies.delete(:user_id, cookie_delete_options)
      @current_user = nil
    end

    def cookie_delete_options
      return {domain: 'glowfic-staging.herokuapp.com'} if request.host.include?('staging')
      return {domain: '.glowfic.com'} if Rails.env.production?
      {}
    end

    def set_user
      @current_user ||= User.find_by_id(session[:user_id])
      return unless @current_user
      set_user_token
    end

    def set_user_token
      expiration = session[:api_token].try(:[], "expires").to_i
      session[:api_token] = nil if Time.zone.now.to_i > expiration
      session[:api_token] ||= {
        value: Authentication.generate_api_token(@current_user),
        expires: Authentication::EXPIRY.from_now.to_i
      }
    end
  end
end
