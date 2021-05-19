class Tag::SettingTag < ApplicationRecord
  self.table_name = 'tag_tags'

  belongs_to :child_setting, class_name: 'Setting', foreign_key: :tagged_id, inverse_of: :child_setting_tags, optional: true
  belongs_to :parent_setting, class_name: 'Setting', foreign_key: :tag_id, inverse_of: :parent_setting_tags, optional: true

  validates :child_setting, uniqueness: { scope: :parent_setting }
end
