class Setting::Post < ApplicationRecord
  self.table_name = 'setting_posts'

  belongs_to :post, class_name: '::Post', inverse_of: :setting_posts, optional: false
  belongs_to :setting, class_name: '::Setting', inverse_of: :setting_characters, optional: false

  validates :post, uniqueness: { scope: :tag }
end
