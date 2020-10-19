# frozen_string_literal: true
require Rails.root.join('lib', 'memorylogic')

class ApplicationController < ActionController::Base
  include Authentication::Web
  include Memorylogic
  include Translations
  include ErrorRendering

  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_token

  before_action :check_tos
  before_action :check_permanent_user
  before_action :show_password_warning
  before_action :require_glowfic_domain
  before_action :set_login_gon
  before_action :check_forced_logout
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
      redirect_to continuities_path
    end
  end

  def handle_invalid_token
    flash[:error] = 'Oops, looks like your session expired! Please try another tab or log in again to resume glowficcing.'
    flash[:error] += ' If you were writing a reply, it has been cached for your next page load.'
    session[:attempted_reply] = params[:reply] if params[:reply].present?
    redirect_to root_path
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

  def tos_skippable?
    return true if Rails.env.test? && params[:force_tos].nil?
    return true unless standard_request?
    return true if params[:tos_check].present?
    return true if ['about', 'sessions', 'password_resets'].include?(params[:controller])
    return true if params[:controller] == 'users' && params[:action] == 'new'

    tos_version = logged_in? ? current_user.tos_version : cookies[:accepted_tos]
    tos_version.to_i >= User::CURRENT_TOS_VERSION
  end
  helper_method :tos_skippable?

  def posts_from_relation(relation, no_tests: true, with_pagination: true, select: '', max: false, with_unread: false, show_blocked: false)
    posts_count = relation.visible_to(current_user).except(:select, :order, :group).count('DISTINCT posts.id')
    posts = posts_list_relation(relation, no_tests: no_tests, select: select, max: max, show_blocked: show_blocked)
    posts = posts.paginate(page: page, total_entries: posts_count) if with_pagination
    calculate_view_status(posts, with_unread: with_unread) if logged_in?
    posts
  end
  helper_method :posts_from_relation

  def posts_list_relation(relation, no_tests: true, select: '', max: false, show_blocked: false)
    select = if max
      <<~SQL
        posts.*,
        max(boards.name) as board_name,
        max(users.username) as last_user_name,
        bool_or(users.deleted) as last_user_deleted
        #{select}
      SQL
    else
      <<~SQL
        posts.*,
        boards.name as board_name,
        users.username as last_user_name,
        users.deleted as last_user_deleted
        #{select}
      SQL
    end

    posts = relation
      .select(select)
      .visible_to(current_user)
      .joins(:board)
      .joins(:last_user)
      .includes(:authors)
      .with_has_content_warnings
      .with_reply_count

    posts = posts.where.not(id: current_user.hidden_posts) if logged_in? && !show_blocked
    posts = posts.no_tests if no_tests
    posts
  end

  def calculate_view_status(posts, with_unread: false)
    post_views = Post::View.where(user_id: current_user.id).where.not(read_at: nil)
    @opened_ids ||= post_views.pluck(:post_id)

    opened_posts = post_views.where(post_id: posts.map(&:id)).select([:post_id, :read_at])
    unread_views = opened_posts.select do |view|
      post = posts.detect { |p| p.id == view.post_id }
      post && view.read_at < post.tagged_at
    end

    @unread_ids ||= []
    @unread_ids += unread_views.map(&:post_id)

    if with_unread
      @unread_counts = Reply.where(post_id: @unread_ids).joins('INNER JOIN post_views ON replies.post_id = post_views.post_id')
      @unread_counts = @unread_counts.where(post_views: {user_id: current_user.id})
      @unread_counts = @unread_counts.where('replies.created_at > post_views.read_at').group(:post_id).count
    end
  end

  attr_reader :unread_ids, :opened_ids, :unread_counts
  # unread_ids and unread_counts do not necessarily include fully unread posts
  helper_method :unread_ids, :opened_ids, :unread_counts

  def generate_short(msg)
    short_msg = Glowfic::Sanitizers.full(msg) # strip all tags, replacing appropriately with spaces
    return short_msg if short_msg.length <= 75
    short_msg[0...73] + '…' # make the absolute max length 75 characters
  end
  helper_method :generate_short

  private

  def check_forced_logout
    return unless logged_in?
    return unless current_user.suspended? || current_user.deleted?
    logout
  end

  def show_password_warning
    return unless logged_in?
    return unless current_user.salt_uuid.nil?
    logout
    flash.now[:error] = "Because Marri accidentally made passwords a bit too secure, you must log back in to continue using the site."
  end

  def store_location
    return unless standard_request?
    session[:previous_url] = request.fullpath
  end

  def set_login_gon
    gon.logged_in = logged_in?
    gon.api_token = session[:api_token]["value"] if logged_in?
  end

  def set_timezone(&block)
    return yield unless logged_in?
    return yield unless current_user.timezone
    Time.use_zone(current_user.timezone, &block)
  end

  def require_glowfic_domain
    return unless Rails.env.production? || params[:force_domain] # for testability
    return unless standard_request?
    return if request.host.include?('glowfic.com')
    return if request.host.include?('glowfic-staging.herokuapp.com')
    glowfic_url = root_url(host: ENV['DOMAIN_NAME'], protocol: 'https')[0...-1] + request.fullpath # strip double slash
    redirect_to glowfic_url, status: :moved_permanently
  end

  def check_tos
    return if tos_skippable?

    store_location
    @page_title = 'Accept the TOS'
    render 'about/accept_tos' and return if logged_in?
    use_javascript('accept_tos')
  end

  def standard_request?
    request.get? && !request.xhr?
  end

  def log_error(exception)
    data = {
      response_status: params[:response_status],
      response_body: params[:response_body],
      response_text: params[:response_text],
      user_id: current_user.try(:id)
    }
    ExceptionNotifier.notify_exception(exception, data: data)
  end

  def associated_model
    controller_path.classify.constantize
  end
end
