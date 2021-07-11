class CharacterTag < ApplicationRecord
  belongs_to :character, inverse_of: :character_tags, optional: false
  belongs_to :tag, inverse_of: :character_tags, optional: true # TODO: This is required, fix bug around validation if it is set as such
  belongs_to :setting, foreign_key: :tag_id, inverse_of: :character_tags, optional: true
  belongs_to :gallery_group, foreign_key: :tag_id, inverse_of: :character_tags, optional: true

  validates :character, uniqueness: { scope: :tag }

  after_create :add_galleries_to_character
  after_destroy :remove_galleries_from_character

  def add_galleries_to_character
    return if gallery_group.nil? # skip non-gallery_groups
    joined_galleries = gallery_group.galleries.where(id: character.characters_galleries.map(&:gallery_id)).pluck(:id)
    galleries = gallery_group.galleries.where(user_id: character.user_id).where.not(id: joined_galleries)
    galleries.each do |gallery|
      character.characters_galleries.create(gallery_id: gallery.id, added_by_group: true)
    end
    joins = character.characters_galleries.select{|cg| gallery_group.gallery_ids.include?(cg.gallery_id)}
    joins.select(&:marked_for_destruction?).each(&:unmark_for_destruction)
  end

  def remove_galleries_from_character
    return if gallery_group.nil? # skip non-gallery_groups
    galleries = gallery_group.galleries.where(user_id: character.user_id)
    joined_group_galleries = (character.gallery_groups - [gallery_group]).collect(&:galleries).flatten
    joined_group_galleries = joined_group_galleries.select{ |gallery| gallery.user_id = character.user_id }.map(&:id)
    galleries = galleries.where.not(id: joined_group_galleries).pluck(:id)
    character.characters_galleries.select{ |cg| galleries.include?(cg.gallery_id) && cg.added_by_group }.each(&:mark_for_destruction)
  end
end
