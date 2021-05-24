class Setting::Character < ApplicationRecord
  self.table_name = 'setting_characters'

  belongs_to :character, class_name: '::Character', inverse_of: :setting_characters, optional: false
  belongs_to :setting, class_name: '::Setting', inverse_of: :setting_characters, optional: false

  validates :character, uniqueness: { scope: :setting }
end
