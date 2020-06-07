class Setting < Tag
  acts_as_ordered_taggable_on :settings

  has_many :parents, through: :taggings, source: :tag, dependent: :destroy
  has_many :children, through: :child_taggings, source: :taggable, source_type: "ActsAsTaggableOn::Tag", dependent: :destroy
end
