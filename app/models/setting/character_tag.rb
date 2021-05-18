class Setting::CharacterTag < ApplicationRecord
  belongs_to :character, inverse_of: :character_tags, optional: false
  belongs_to :setting, foreign_key: :tag_id, inverse_of: :character_tags, optional: false

  validates :character, uniqueness: { scope: :tag }
end
