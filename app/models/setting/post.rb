class Setting::Post < ApplicationRecord
  self.table_name = 'setting_posts'

  belongs_to :post, inverse_of: :setting_posts, optional: false
  belongs_to :setting, inverse_of: :setting_posts, optional: false

  validates :post, uniqueness: { scope: :tag }
end
