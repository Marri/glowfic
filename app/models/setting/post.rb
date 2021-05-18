class Setting::Post < ApplicationRecord
  belongs_to :post, inverse_of: :setting_posts, optional: false
  belongs_to :setting, inverse_of: :setting_posts, optional: false

  validates :post, uniqueness: { scope: :tag }
end
