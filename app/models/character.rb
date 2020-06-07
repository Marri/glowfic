class Character < ApplicationRecord
  include Presentable

  belongs_to :user, optional: false
  belongs_to :template, inverse_of: :characters, optional: true
  belongs_to :default_icon, class_name: 'Icon', inverse_of: false, optional: true
  belongs_to :character_group, optional: true
  has_many :replies, dependent: false
  has_many :posts, dependent: false # These are handled in callbacks
  has_many :aliases, class_name: 'CharacterAlias', inverse_of: :character, dependent: :destroy
  has_many :reply_drafts, dependent: :nullify
  has_one :active_user, inverse_of: :active_character, class_name: 'User', foreign_key: :active_character_id, dependent: :nullify

  has_many :characters_galleries, inverse_of: :character, autosave: true, dependent: :destroy
  accepts_nested_attributes_for :characters_galleries, allow_destroy: true
  has_many :galleries, through: :characters_galleries, dependent: :destroy
  has_many :icons, -> { group('icons.id').ordered }, through: :galleries

  has_many :character_tags, inverse_of: :character

  validates :name,
    presence: true,
    length: { maximum: 255 }
  validate :valid_group, :valid_galleries, :valid_default_icon

  attr_accessor :group_name

  before_validation :strip_spaces
  after_destroy :clear_char_ids
  before_save :update_galleries

  scope :ordered, -> { order(name: :asc).order(Arel.sql('lower(screenname) asc'), created_at: :asc, id: :asc) }
  scope :with_name, -> (charname) { where("lower(concat_ws(' | ', name, nickname, screenname)) LIKE ?", "%#{charname.downcase}%") }

  accepts_nested_attributes_for :template, reject_if: :all_blank

  nilify_blanks

  audited on: :update, mod_only: true, update_with_comment_only: false

  acts_as_ordered_taggable_on :settings, :gallery_groups

  def editable_by?(user)
    self.class.editable_by?(user, self.user_id)
  end

  def self.editable_by?(user, user_id)
    return false unless user
    return true if user_id == user.id
    user.has_permission?(:edit_characters)
  end

  def deletable_by?(user)
    self.class.deletable_by?(user, self.user_id)
  end

  def self.deletable_by?(user, user_id)
    return false unless user
    return true if user_id == user.id
    user.has_permission?(:delete_characters)
  end

  def recent_posts
    return @recent unless @recent.nil?
    reply_ids = replies.group(:post_id).pluck(:post_id)
    post_ids = posts.select(:id).map(&:id)
    @recent ||= Post.where(id: (post_ids + reply_ids).uniq).ordered
  end

  def selector_name
    [name, nickname, screenname].compact.join(' | ')
  end

  def reorder_galleries(_gallery=nil)
    # public so that it can be called from CharactersGallery.after_destroy
    galleries = CharactersGallery.where(character_id: id).ordered
    return unless galleries.present?

    galleries.each_with_index do |other, index|
      next if other.section_order == index
      other.section_order = index
      other.save
    end
  end

  def ungrouped_gallery_ids
    characters_galleries.reject(&:added_by_group?).map(&:gallery_id)
  end

  def ungrouped_gallery_ids=(new_ids)
    new_ids -= ['']
    new_ids = new_ids.map(&:to_i).uniq
    group_gallery_ids = Gallery.where(user: user).tagged_with(gallery_group_list_was)
    characters_galleries.each do |char_gal|
      gallery_id = char_gal.gallery_id
      if new_ids.include?(gallery_id)
        # make sure added_by_group is false for galleries in the new ids
        char_gal.added_by_group = false
        char_gal.unmark_for_destruction if char_gal.marked_for_destruction?
        new_ids.delete(gallery_id)
      else
        char_gal.added_by_group = true
        # destroy joins that are not in the new set of IDs and are not in gallery groups
        char_gal.mark_for_destruction unless group_gallery_ids.include?(gallery_id)
      end
    end
    # add any new galleries
    self.galleries << Gallery.where(id: new_ids) if new_ids.present?
  end

  def character_gallery_for(gallery)
    characters_galleries.find_by(gallery_id: gallery)
  end

  private

  def valid_group
    return unless character_group_id == 0
    @group = CharacterGroup.new(user: user, name: group_name)
    return if @group.valid?
    @group.errors.messages.each do |k, v|
      v.each { |val| errors.add('group '+k.to_s, val) }
    end
  end

  def valid_galleries
    errors.add(:galleries, "must be yours") if galleries.present? && galleries.detect{|g| g.user_id != user.id}
  end

  def valid_default_icon
    return unless default_icon.present?
    return if default_icon.user_id == user_id
    errors.add(:default_icon, "must be yours")
  end

  def clear_char_ids
    UpdateModelJob.perform_later(Post.to_s, {character_id: id}, {character_id: nil})
    UpdateModelJob.perform_later(Reply.to_s, {character_id: id}, {character_id: nil})
  end

  def strip_spaces
    self.pb = self.pb.strip if self.pb.present?
  end

  def update_galleries
    return unless gallery_group_list_changed?

    present_galleries = ActsAsTaggableOn::Tagging.where(taggable_type: 'Gallery').joins(:tag)
    present_galleries = present_galleries.joins("INNER JOIN galleries ON galleries.id = taggings.taggable_id")
    present_galleries = present_galleries.where(tags: {type: 'GalleryGroup', name: gallery_group_list})
    present_galleries = present_galleries.where(galleries: {user_id: user_id}).pluck(:taggable_id)

    if new_record? || gallery_group_list_was.nil?
      add_galleries_from_group(present_galleries)
    else
      add_galleries_from_group(present_galleries) unless (gallery_group_list - gallery_group_list_was).empty?
      remove_galleries_from_group(present_galleries) unless (gallery_group_list_was - gallery_group_list).empty?
    end
  end

  def add_galleries_from_group(present_galleries)
    existing_links = characters_galleries.select(:gallery_id)
    new_galleries = Gallery.where(id: present_galleries).where.not(id: existing_links)
    new_galleries.each do |gallery|
      creates = {gallery: gallery, added_by_group: true}
      if new_record?
        characters_galleries.new(creates)
      else
        characters_galleries.create!(creates)
      end
    end
  end

  def remove_galleries_from_group(present_galleries)
    rem_cgs = characters_galleries.where(added_by_group: true)
    rem_cgs = rem_cgs.where.not(gallery_id: present_galleries) if gallery_group_list.present?
    rem_cgs.destroy_all
  end
end
