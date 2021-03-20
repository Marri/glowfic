class Block < ApplicationRecord
  belongs_to :blocking_user, class_name: 'User', optional: false, inverse_of: :blocks
  belongs_to :blocked_user, class_name: 'User', optional: false

  validates :blocking_user_id, uniqueness: { scope: :blocked_user_id }
  validate :not_blocking_self
  validate :option_chosen

  audited on: [:update, :destroy], update_with_comment_only: false

  scope :ordered, -> { includes(:blocked_user).sort_by { |block| [block.blocked_user.username.downcase] } }

  after_create :mark_messages_read
  after_commit :invalidate_caches

  enum hide_me: {
    none: 0,
    posts: 1,
    all: 2
  }, _prefix: true

  enum hide_them: {
    none: 0,
    posts: 1,
    all: 2
  }, _prefix: true

  CACHE_VERSION = 4

  def editable_by?(user)
    return false unless user
    self.blocking_user_id == user.id
  end

  def hide_my_posts?
    !hide_me_none?
  end

  def hide_their_posts?
    !hide_them_none?
  end

  def self.cache_string_for(user_id, string='blocked')
    "#{Rails.env}.#{CACHE_VERSION}.#{string}_posts.#{user_id}"
  end

  private

  def not_blocking_self
    return unless blocking_user == blocked_user
    errors.add(:user, "cannot block themself")
  end

  def option_chosen
    return if hide_my_posts? || hide_their_posts? || block_interactions?
    errors.add(:block, "must choose at least one action to prevent")
  end

  def mark_messages_read
    Message.where(unread: true, sender_id: blocked_user_id, recipient_id: blocking_user_id).find_each do |message|
      message.unread = false
      message.save!
    end
  end

  def invalidate_caches
    Rails.cache.delete(Block.cache_string_for(self.blocking_user.id, 'hidden'))
    Rails.cache.delete(Block.cache_string_for(self.blocked_user.id, 'blocked'))
  end
end
