class Setting < ApplicationRecord
  belongs_to :user, optional: false
  has_many :setting_posts, class_name: 'Setting::Post', dependent: :destroy, inverse_of: :setting
  has_many :posts, through: :setting_posts, dependent: :destroy

  has_many :setting_characters, class_name: 'Setting::Character', dependent: :destroy, inverse_of: :setting
  has_many :characters, through: :setting_characters, dependent: :destroy

  has_many :parent_setting_tags, class_name: 'Setting::SettingTag', foreign_key: :tag_id, inverse_of: :parent_setting, dependent: :destroy
  has_many :child_setting_tags, class_name: 'Setting::SettingTag', foreign_key: :tagged_id, inverse_of: :child_setting, dependent: :destroy

  has_many :parent_settings, -> { ordered_by_tag_tag }, class_name: 'Setting', through: :child_setting_tags,
    source: :parent_setting, dependent: :destroy
  has_many :child_settings, class_name: 'Setting', through: :parent_setting_tags, source: :child_setting, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :ordered_by_name, -> { order(name: :asc) }

  scope :ordered_by_id, -> { order(id: :asc) }

  scope :ordered_by_char_tag, -> { order('setting_characters.id ASC') }

  scope :ordered_by_post_tag, -> { order('setting_posts.id ASC') }

  scope :ordered_by_tag_tag, -> { order('setting_tags.id ASC') }

  scope :with_character_counts, -> {
    # rubocop:disable Style/TrailingCommaInArguments
    select(
      <<~SQL
        (
          SELECT COUNT(DISTINCT setting_characters.character_id)
          FROM setting_characters
          WHERE setting_characters.setting_id = settings.id
        )
        AS character_count
      SQL
    )
    # rubocop:enable Style/TrailingCommaInArguments
  }

  def editable_by?(user)
    return false unless user
    return true if deletable_by?(user)
    return true if user.has_permission?(:edit_tags)
    !owned?
  end

  def deletable_by?(user)
    return false unless user
    return true if user.has_permission?(:delete_tags)
    user.id == user_id
  end

  def as_json(_options={})
    {id: self.id, text: self.name}
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

  def type
    'setting'
  end

  def merge_with(other_setting)
    transaction do
      # rubocop:disable Rails/SkipsModelValidations
      other_posts = Setting::Post.where(setting_id: other_setting.id)
      other_posts.where(post_id: setting_posts.select(:post_id).distinct.pluck(:post_id)).delete_all
      other_posts.update_all(setting_id: self.id)
      other_characters = Setting::Character.where(setting_id: other_setting.id)
      other_characters.where(character_id: setting_characters.select(:character_id).distinct.pluck(:character_id)).delete_all
      other_characters.update_all(setting_id: self.id)
      Setting::SettingTag.where(tag_id: other_setting.id, tagged_id: self.id).delete_all
      Setting::SettingTag.where(tag_id: self.id, tagged_id: other_setting.id).delete_all
      Setting::SettingTag.where(tag_id: other_setting.id).update_all(tag_id: self.id)
      Setting::SettingTag.where(tagged_id: other_setting.id).update_all(tagged_id: self.id)
      other_setting.destroy!
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
