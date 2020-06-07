class Tag < ApplicationRecord
  belongs_to :user, optional: false
  has_many :post_tags, dependent: :destroy, inverse_of: :tag
  has_many :posts, through: :post_tags, dependent: :destroy
  has_many :character_tags, dependent: :destroy, inverse_of: :tag
  has_many :characters, through: :character_tags, dependent: :destroy
  has_many :gallery_tags, dependent: :destroy, inverse_of: :tag
  has_many :galleries, through: :gallery_tags, dependent: :destroy

  TYPES = %w(Setting Label ContentWarning GalleryGroup)

  validates :name, :type, presence: true
  validates :name, uniqueness: { scope: :type }

  scope :ordered_by_type, -> { order(type: :desc, name: :asc) }

  scope :ordered_by_name, -> { order(name: :asc) }

  scope :ordered_by_id, -> { order(id: :asc) }

  scope :ordered_by_char_tag, -> { order('character_tags.id ASC') }

  scope :ordered_by_gallery_tag, -> { order('gallery_tags.id ASC') }

  scope :ordered_by_post_tag, -> { order('post_tags.id ASC') }

  scope :ordered_by_tag_tag, -> { order('tag_tags.id ASC') }

  scope :with_character_counts, -> {
    select("(SELECT COUNT(DISTINCT character_tags.character_id) FROM character_tags WHERE character_tags.tag_id = tags.id) AS character_count")
  }

  def editable_by?(user)
    return false unless user
    return true if deletable_by?(user)
    return true if user.has_permission?(:edit_tags)
    return false unless is_a?(Setting)
    !owned?
  end

  def deletable_by?(user)
    return false unless user
    return true if user.has_permission?(:delete_tags)
    user.id == user_id
  end

  def as_json(options={})
    tag_json = {id: self.id, text: self.name}
    return tag_json unless options[:include].present?
    if options[:include].include?(:gallery_ids)
      g_tags = gallery_tags.joins(:gallery)
      g_tags = g_tags.where(galleries: {user_id: options[:user_id]}) if options[:user_id].present?
      tag_json[:gallery_ids] = g_tags.pluck(:gallery_id)
    end
    tag_json
  end

  def id_for_select
    return id if persisted? # id present on unpersisted records when associated record is invalid
    "_#{name}"
  end

  def post_count
    return read_attribute(:post_count) if has_attribute?(:post_count)
    posts.count
  end

  def character_count
    return read_attribute(:character_count) if has_attribute?(:character_count)
    characters.count
  end

  def merge_with(other_tag)
    return false unless type == other_tag.type
    transaction do
      unless type == GalleryGroup.to_s
        theirs = PostTag.where(tag: other_tag)
        theirs.where(post_id: post_ids).delete_all
        theirs.update_all(tag_id: self.id)
      end
      if [GalleryGroup, Setting].map(&:to_s).include?(type)
        theirs = CharacterTag.where(tag: other_tag)
        theirs.where(character_id: character_ids).delete_all
        theirs.update_all(tag_id: self.id)
      end
      if type == GalleryGroup.to_s
        theirs = GalleryTag.where(tag: other_tag)
        theirs.where(gallery_id: gallery_ids).delete_all
        theirs.update_all(tag_id: self.id)
      end
      if type == Setting.to_s
        their_children = TagTag.where(tag_id: other_tag.id)
        their_children.where(tagged_id: child_setting_ids).delete_all
        their_children.update_all(tag_id: self.id)
        their_parents = TagTag.where(tagged_id: other_tag.id)
        their_parents.where(tag_id: parent_setting_ids).delete_all
        their_parents.update_all(tagged_id: self.id)
      end
      other_tag.destroy!
    end
  end
end
