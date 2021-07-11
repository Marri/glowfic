class NotificationsController < ApplicationController
  before_action :login_required

  def index
    @page_title = "Notifications"
    @notifications = current_user.notifications.visible_to(current_user).ordered.paginate(page: page)

    post_ids = @notifications.map(&:post_id).reject(&:blank?)
    @posts = posts_from_relation(Post.where(id: post_ids)).index_by(&:id)
  end

  def mark
    notifications = Notification.where(id: params[:marked_ids], user: current_user)

    case params[:commit]
      when "Mark Read"
        notifications.each { |notif| notif.update(unread: false, read_at: notif.read_at || Time.zone.now) }
      when "Mark Unread"
        notifications.each { |notif| notif.update(unread: true) }
      when "Delete"
        notifications.destroy_all
      else
        flash[:error] = "Could not perform unknown action."
        redirect_to notifications_path and return
    end

    flash[:success] = "Messages updated"
    redirect_to notifications_path
  end
end
