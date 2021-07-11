class Notification < ApplicationRecord
  belongs_to :user, inverse_of: :notifications, optional: false
  belongs_to :post, inverse_of: :notifications, optional: true

  scope :unread, -> { where(unread: true) }
  scope :ordered, -> { order(created_at: :desc) }

  scope :visible_to, -> (user) {
    left_outer_joins(:post)
      .merge(Post.visible_to(user))
      .where.not(post_id: user.hidden_posts)
      .or(left_outer_joins(:post).where(post_id: nil))
  }

  enum notification_type: {
    import_success: 0,
    import_fail: 1,
    new_favorite_post: 2,
    joined_favorite_post: 3,
  }

  def self.notify_user(user, type, post: nil, error: nil)
    Notification.create!(user: user, notification_type: type, post: post, error_msg: error)
  end
end
