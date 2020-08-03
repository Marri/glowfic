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

  has_many :characters_galleries, inverse_of: :character, dependent: :destroy
  accepts_nested_attributes_for :characters_galleries, allow_destroy: true
  has_many :galleries, through: :characters_galleries, dependent: :destroy
  has_many :icons, -> { group('icons.id').ordered }, through: :galleries

  has_many :character_tags, inverse_of: :character, dependent: :destroy
  has_many :settings, -> { ordered_by_char_tag }, through: :character_tags, source: :setting, dependent: :destroy
  has_many :gallery_groups, -> { ordered_by_char_tag }, through: :character_tags, source: :gallery_group, dependent: :destroy

  validates :name,
    presence: true,
    length: { maximum: 255 }
  validate :valid_group, :valid_galleries, :valid_default_icon

  attr_accessor :group_name

  before_validation :strip_spaces
  after_destroy :clear_char_ids

  scope :ordered, -> { order(name: :asc).order(Arel.sql('lower(screenname) asc'), created_at: :asc, id: :asc) }
  scope :with_name, -> (charname) { where("lower(concat_ws(' | ', name, nickname, screenname)) LIKE ?", "%#{charname.downcase}%") }

  accepts_nested_attributes_for :template, reject_if: :all_blank

  nilify_blanks

  audited on: :update, mod_only: true, update_with_comment_only: false

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
    @recent ||= Post.where(id: replies.select(:post_id).distinct.pluck(:post_id)).ordered
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

  # WARNING: this method *will make changes* when used, not just when saved!!!
  # This is so it can interact with group_gallery_ids properly instead of having
  # to use an intricate system to find the current character galleries prior to
  # persisting i.e. it's so ungrouped_gallery_ids= and various callbacks for
  # gallery_group_ids= interact properly
  def ungrouped_gallery_ids=(new_ids)
    new_ids -= ['']
    new_ids = new_ids.map(&:to_i)
    group_gallery_ids = gallery_groups.joins(:gallery_tags).except(:order).pluck(Arel.sql('distinct gallery_tags.gallery_id'))
    new_chargals = []
    transaction do
      characters_galleries.each do |char_gal|
        gallery_id = char_gal.gallery_id
        if new_ids.include?(gallery_id)
          # add relevant old galleries, making sure added_by_group is false
          char_gal.added_by_group = false
          new_chargals << char_gal
          new_ids.delete(gallery_id)
        elsif group_gallery_ids.include?(gallery_id)
          # add relevant old group galleries, added_by_group being true
          char_gal.added_by_group = true
          new_chargals << char_gal
          group_gallery_ids.delete(gallery_id)
        else
          # destroy joins that are not in the new set of IDs
          char_gal.destroy
        end
      end
      new_ids.each do |gallery_id|
        # add any leftover new galleries
        new_chargals << CharactersGallery.new(gallery_id: gallery_id, character_id: id, added_by_group: false)
      end
      # leftover galleries from gallery groups will be added by that model
      self.characters_galleries = new_chargals
      if persisted?
        self.update(characters_galleries: new_chargals)
      else
        self.assign_attributes(characters_galleries: new_chargals)
      end
    end
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
end
