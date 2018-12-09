module Blockable
  extend ActiveSupport::Concern

  included do
    has_many :blocks, inverse_of: :blocking_user
  end

  def can_interact_with?(user)
    !user_ids_uninteractable.include?(user.id)
  end

  def has_interaction_blocked?(user)
    user_ids_blocked_interaction.include?(user.id)
  end

  def user_ids_blocked_interaction
    Block.where(block_interactions: true, blocking_user: self).pluck(:blocked_user_id)
  end

  def user_ids_blocking_interaction
    Block.where(block_interactions: true, blocked_user: self).pluck(:blocking_user_id)
  end

  def user_ids_uninteractable
    (user_ids_blocking_interaction + user_ids_blocked_interaction).uniq
  end
end
