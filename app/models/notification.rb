class Notification < ApplicationRecord
  belongs_to :user, inverse_of: :notifications, optional: false
  belongs_to :post, optional: true
  scope :unread, -> { where(unread: true) }

  enum notification_type: {
    import_success: 0,
    import_fail: 1,
    new_favorite_post: 2,
    joined_favorite_post: 3,
  }

  def self.notify_user(user, type, post: nil, error: nil)
    notif = Notification.new(user: user, notification_type: type)
    notif.post = post if post
    notif.error_msg = error if error
    notif.save!
  end
end
