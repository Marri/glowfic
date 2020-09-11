class PostLink < ApplicationRecord
  belongs_to :linking_post, class_name: 'Post', inverse_of: :linked_post_joins, optional: false
  belongs_to :linked_post, class_name: 'Post', inverse_of: :linking_post_joins, optional: false

  TYPES = ['related to', 'inspired by', 'an AU of', 'a sequel to', 'cocurrent with']

  validates :linking_post, uniqueness: { scope: :linked_post }
  validates :relationship, presence: true
  validate :different_posts

  private

  def different_posts
    errors.add(:linked_post, 'cannot be the same post') if linking_post_id == linked_post_id
  end
end
