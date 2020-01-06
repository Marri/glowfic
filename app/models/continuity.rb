class Continuity < ApplicationRecord
  include Presentable
  include Viewable

  ID_SITETESTING = 4

  has_many :posts, dependent: false # This is handled in callbacks
  has_many :subcontinuities, dependent: :destroy
  has_many :favorites, as: :favorite, inverse_of: :favorite, dependent: :destroy
  belongs_to :creator, class_name: 'User', inverse_of: false, optional: false

  has_many :continuity_authors, inverse_of: :continuity, dependent: :destroy
  has_many :authors, class_name: 'User', through: :continuity_authors, source: :user, dependent: :destroy
  has_many :continuity_writers, -> { where(cameo: false) }, class_name: 'ContinuityAuthor', inverse_of: :continuity
  has_many :writers, class_name: 'User', through: :continuity_writers, source: :user, dependent: :destroy
  has_many :continuity_cameos, -> { where(cameo: true) }, class_name: 'ContinuityAuthor', inverse_of: :continuity
  has_many :cameos, class_name: 'User', through: :continuity_cameos, source: :user, dependent: :destroy
  has_many :coauthors, ->(continuity) { where.not(id: continuity.creator_id) }, class_name: 'User', through: :continuity_writers, source: :user, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  after_create :add_creator_to_authors
  after_destroy :move_posts_to_sandbox

  scope :ordered, -> { order(pinned: :desc, name: :asc) }

  def open_to?(user)
    return false unless user
    return true unless self.authors_locked?
    return true if creator_id == user.id
    continuity_authors.where(user_id: user.id).exists?
  end

  def editable_by?(user)
    return false unless user
    return true if creator_id == user.id
    return true if user.has_permission?(:edit_continuities)
    return false if creator.deleted?
    continuity_writers.where(user_id: user.id).exists?
  end

  def ordered?
    authors_locked? || subcontinuities.exists?
  end

  private

  def move_posts_to_sandbox
    # TODO don't hard code sandbox continuity_id
    UpdateModelJob.perform_later(Post.to_s, {continuity_id: id}, {continuity_id: 3, section_id: nil})
  end

  def add_creator_to_authors
    continuity_authors.create!(user: creator)
  end

  def fix_ordering
    # this should ONLY be called by an admin for emergency fixes
    subcontinuities.ordered.each_with_index do |section, index|
      next if section.section_order == index
      section.update_columns(section_order: index)
    end
    posts.where(section_id: nil).ordered_in_section.each_with_index do |post, index|
      next if post.section_order == index
      post.update_columns(section_order: index)
    end
  end
end
