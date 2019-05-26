# frozen_string_literal: true
require Rails.root.join('lib', 'memorylogic')

class ApplicationController < ActionController::Base
  include Authentication
  include Memorylogic

  protect_from_forgery with: :exception
  before_action :check_tos
  before_action :check_permanent_user
  before_action :show_password_warning
  before_action :require_glowfic_domain
  before_action :set_login_gon
  before_action :check_suspension
  around_action :set_timezone
  after_action :store_location

  protected

  def login_required
    unless logged_in?
      flash[:error] = "You must be logged in to view that page."
      redirect_to root_path
    end
  end

  def logout_required
    if logged_in?
      flash[:error] = "You are already logged in."
      redirect_to boards_path
    end
  end

  def check_suspension
    return unless logged_in?
    return unless current_user.suspended?
    logout
  end

  def show_password_warning
    return unless logged_in?
    return unless current_user.salt_uuid.nil?
    logout
    flash.now[:error] = "Because Marri accidentally made passwords a bit too secure, you must log back in to continue using the site."
  end

  def use_javascript(js)
    @javascripts ||= []
    @javascripts << js
  end

  VALID_PAGES = ['last', 'unread']
  def page
    return @page if @page
    return (@page = 1) unless params[:page]
    @page = params[:page]
    return @page if VALID_PAGES.include?(@page)
    @page = @page.to_i
    return @page if @page > 0
    flash.now[:error] = "Page not recognized, defaulting to page 1."
    @page = 1
  end
  helper_method :page

  attr_writer :page

  def per_page
    default = 25 # browser.mobile? ? -1 : 25
    per = (params[:per_page] || current_user.try(:per_page) || default)
    per = 100 if per == 'all' || per.to_i > 100
    per = default if per.to_i.zero?
    @per_page ||= per.to_i
  end
  helper_method :per_page

  def page_view
    return @view if @view
    if logged_in?
      @view = params[:view] || current_user.default_view
    else
      @view = session[:view] = params[:view] || session[:view] || 'icon'
    end
  end
  helper_method :page_view

  def store_location
    return unless request.get?
    return if request.xhr?
    session[:previous_url] = request.fullpath
  end

  def set_timezone(&block)
    return yield unless logged_in?
    return yield unless current_user.timezone
    Time.use_zone(current_user.timezone, &block)
  end

  def require_glowfic_domain
    return unless Rails.env.production? || params[:force_domain] # for testability
    return unless request.get?
    return if request.xhr?
    return if request.host.include?('glowfic.com')
    return if request.host.include?('glowfic-staging.herokuapp.com')
    glowfic_url = root_url(host: ENV['DOMAIN_NAME'], protocol: 'https')[0...-1] + request.fullpath # strip double slash
    redirect_to glowfic_url, status: :moved_permanently
  end

  def set_login_gon
    gon.logged_in = logged_in?
  end

  def check_tos
    return if tos_skippable?

    store_location
    @page_title = 'Accept the TOS'
    render 'about/accept_tos' and return if logged_in?
    use_javascript('accept_tos')
  end

  def tos_skippable?
    return true if Rails.env.test? && params[:force_tos].nil?
    return true if request.xhr?
    return true unless request.get?
    return true if params[:tos_check].present?
    return true if ['about', 'sessions'].include?(params[:controller])
    return true if params[:controller] == 'users' && params[:action] == 'new'

    tos_version = logged_in? ? current_user.tos_version : cookies[:accepted_tos]
    tos_version.to_i >= User::CURRENT_TOS_VERSION
  end
  helper_method :tos_skippable?

  def post_or_reply_link(reply)
    return unless reply.id.present?
    if reply.is_a?(Reply)
      reply_path(reply, anchor: "reply-#{reply.id}")
    else
      post_path(reply)
    end
  end
  helper_method :post_or_reply_link

  def posts_from_relation(relation, no_tests: true, with_pagination: true, select: '', max: false)
    post_list = PostList.new(relation, no_tests: no_tests, select: select, user: current_user, max: max)
    posts = post_list.format_posts(with_pagination: with_pagination, page: page)
    @opened_ids = post_list.opened_ids
    @unread_ids = post_list.unread_ids
    posts
  end
  helper_method :posts_from_relation

  attr_reader :unread_ids, :opened_ids
  # unread_ids does not necessarily include fully unread posts
  helper_method :unread_ids, :opened_ids

  def generate_short(msg)
    short_msg = Glowfic::Sanitizers.full(msg) # strip all tags, replacing appropriately with spaces
    return short_msg if short_msg.length <= 75
    short_msg[0...73] + '…' # make the absolute max length 75 characters
  end
  helper_method :generate_short
end
