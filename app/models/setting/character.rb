class Setting::Character < ApplicationRecord
  self.table_name = 'setting_characters'

  belongs_to :character, inverse_of: :setting_characters, optional: false
  belongs_to :setting, inverse_of: :setting_characters, optional: false

  validates :character, uniqueness: { scope: :tag }
end
