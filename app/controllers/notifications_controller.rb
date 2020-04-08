class NotificationsController < ApplicationController
  before_action :login_required

  def index
    @notifications = current_user.notifications
  end
end
