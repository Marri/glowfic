class BoardSection < ApplicationRecord
  include Orderable
  include Presentable

  belongs_to :board, inverse_of: :board_sections, optional: false
  has_many :posts, inverse_of: :section, foreign_key: :section_id, dependent: false # This is handled in callbacks

  validates :name, presence: true

  after_destroy :clear_section_ids

  scope :ordered, -> { order(section_order: :asc) }

  private

  def clear_section_ids
    UpdateModelJob.perform_later(Post.to_s, {section_id: id}, {section_id: nil}, audited_user_id)
  end

  def ordered_attributes
    [:board_id]
  end
end
