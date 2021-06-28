class PostViewer < ApplicationRecord
  belongs_to :post, optional: false
  belongs_to :user, optional: false

  validates :post, uniqueness: { scope: :user }

  after_commit :invalidate_cache
  after_commit :notify_followers, on: :create

  CACHE_VERSION = 1

  def self.cache_string_for(user_id)
    "#{Rails.env}.#{CACHE_VERSION}.visible_posts.#{user_id}"
  end

  private

  def invalidate_cache
    Rails.cache.delete(PostViewer.cache_string_for(self.user.id))
  end

  def notify_followers
    return unless post.privacy_access_list?
    NotifyFollowersOfNewPostJob.perform_later(post_id, user_id, 'access')
  end
end
