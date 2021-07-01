class NotificationsController < ApplicationController
  before_action :login_required

  def index
    @notifications = current_user.notifications
  end

  def mark
    notifications = Notification.where(id: params[:marked_ids], user: current_user)

    if params[:commit] == "Mark Read"
      notifications.each { |notif| notif.update(unread: false, read_at: notif.read_at || Time.zone.now) }
    elsif params[:commit] == "Mark Unread"
      notifications.each { |notif| notif.update(unread: true) }
    elsif params[:commit] == "Delete"
      notifications.destroy_all
    else
      flash[:error] = "Could not perform unknown action."
      redirect_to notification_path and return
    end

    flash[:success] = "Messages updated"
    redirect_to notifications_path
  end
end
