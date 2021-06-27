class Post::Author < ApplicationRecord
  belongs_to :post, optional: false
  belongs_to :user, optional: false

  validates :user, uniqueness: { scope: :post }

  after_commit :invalidate_caches, on: [:create, :destroy]
  after_commit :notify_followers, on: :create

  def self.clear_cache_for(authors)
    blocked_ids = Block.where(blocking_user: authors, hide_me: [:posts, :all]).pluck(:blocked_user_id)
    blocked_ids.each { |blocked| Rails.cache.delete(Block.cache_string_for(blocked, 'blocked')) }
    hiding_ids = Block.where(blocked_user: authors, hide_them: [:posts, :all]).pluck(:blocking_user_id)
    hiding_ids.each { |blocker| Rails.cache.delete(Block.cache_string_for(blocker, 'hidden')) }
  end

  private

  def invalidate_caches
    self.class.clear_cache_for(user)
  end

  def notify_followers
    return if post.is_import || post.last_reply&.is_import
    return if user_id == post.user_id
    return unless joined?
    NotifyFollowersOfNewPostJob.perform_later(post_id, user_id, 'join')
  end
end
