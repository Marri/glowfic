class GalleriesIcon < ApplicationRecord
  belongs_to :icon, optional: true # TODO: This is required, fix bug around validation if it is set as such
  belongs_to :gallery, optional: false
  accepts_nested_attributes_for :icon, allow_destroy: true

  after_create :set_has_gallery
  after_destroy :unset_has_gallery
  validates :gallery, uniqueness: { scope: :icon }

  def unset_has_gallery
    return if icon.galleries.present?
    icon.update!(has_gallery: false)
  end

  def set_has_gallery
    return if icon.has_gallery?
    icon.update!(has_gallery: true)
  end
end
