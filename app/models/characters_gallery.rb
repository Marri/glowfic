class CharactersGallery < ApplicationRecord
  belongs_to :character, inverse_of: :characters_galleries, optional: false
  belongs_to :gallery, inverse_of: :characters_galleries, optional: false

  before_create :autofill_order
  after_destroy :reorder_others

  validates :character, uniqueness: { scope: :gallery }

  scope :ordered, -> { order(section_order: :asc) }

  def reorder_others
    character.reorder_galleries
  end

  def autofill_order
    self.section_order = CharactersGallery.where(character_id: character_id).count
  end

  def unmark_for_destruction
    @marked_for_destruction = false
  end
end
