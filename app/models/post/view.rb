class Post::View < ApplicationRecord
  belongs_to :post, optional: false
  belongs_to :user, optional: false

  validates :post, uniqueness: { scope: :user }

  after_create :mark_favorite_read

  private

  def mark_favorite_read
    favorited_continuity = user.favorites.where(favorite: post.board).exists?
    favorited_users = user.favorites.where(favorite: post.joined_authors).exists?
    return unless favorited_continuity || favorited_users

    message = NotifyFollowersOfNewPostJob.notification_about(post, user, unread_only: true)
    return unless message

    message.update!(unread: false, read_at: Time.zone.now)
  end
end
