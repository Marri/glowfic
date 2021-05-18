class PostTag < ApplicationRecord
  belongs_to :post, inverse_of: :post_tags, optional: false
  belongs_to :setting, foreign_key: :tag_id, inverse_of: :post_tags, optional: false

  validates :post, uniqueness: { scope: :tag }
end
