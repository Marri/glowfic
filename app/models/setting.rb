class Setting < Tag
  has_many :parent_setting_tags, class_name: 'Tag::SettingTag', foreign_key: :tag_id, inverse_of: :parent_setting, dependent: :destroy
  has_many :child_setting_tags, class_name: 'Tag::SettingTag', foreign_key: :tagged_id, inverse_of: :child_setting, dependent: :destroy

  has_many :parent_settings, -> { ordered_by_tag_tag }, class_name: 'Setting', through: :child_setting_tags,
    source: :parent_setting, dependent: :destroy
  has_many :child_settings, class_name: 'Setting', through: :parent_setting_tags, source: :child_setting, dependent: :destroy
end
