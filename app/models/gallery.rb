class Gallery < ApplicationRecord
  include Tag::Taggable

  belongs_to :user, optional: false

  has_many :galleries_icons, dependent: :destroy, inverse_of: :gallery
  accepts_nested_attributes_for :galleries_icons, allow_destroy: true
  has_many :icons, -> { ordered }, through: :galleries_icons, dependent: :destroy

  has_many :characters_galleries, inverse_of: :gallery, dependent: :destroy
  has_many :characters, through: :characters_galleries, dependent: :destroy

  has_many :gallery_tags, inverse_of: :gallery, dependent: :destroy,
    after_add: :dirtify_tag_list, after_remove: :dirtify_tag_list
  has_many :gallery_groups, -> { ordered_by_gallery_tag }, through: :gallery_tags, source: :gallery_group, dependent: :destroy

  validates :name, presence: true

  has_tags(gallery_group: GalleryGroup)

  scope :ordered, -> { order('characters_galleries.section_order ASC') }

  scope :ordered_by_name, -> { order(Arel.sql('lower(name) asc'), id: :asc) }

  scope :ordered_by_id, -> { order(id: :asc) }

  scope :with_icon_count, -> {
    joins('LEFT JOIN galleries_icons ON galleries.id = galleries_icons.gallery_id')
      .select("galleries.*, count(galleries_icons.id) as icon_count")
      .group("galleries.id")
  }

  # rubocop:disable Style/TrailingCommaInArguments
  scope :with_gallery_groups, -> {
    # fetches an array of
    # galleries.map(&:gallery_groups).map{|group| [f1: group.id, f2: group.name]}
    # ordered by tag name
    select(
      <<~SQL.squish
        ARRAY(
          SELECT row_to_json(ROW(tags.id, tags.name)) FROM tags
          LEFT JOIN gallery_tags ON gallery_tags.tag_id = tags.id
          WHERE gallery_tags.gallery_id = galleries.id AND tags.type = 'GalleryGroup'
          ORDER BY gallery_tags.id ASC
        ) AS gallery_groups_data_internal
      SQL
    )
  }
  # rubocop:enable Style/TrailingCommaInArguments

  # Converts the internal [{'f1' => id, 'f2' => name}] structure of the retrieved data
  # to [{id => id, name => name}]
  def gallery_groups_data
    return @gallery_groups_data unless @gallery_groups_data.nil?
    if has_attribute?(:gallery_groups_data_internal)
      data_internal = read_attribute(:gallery_groups_data_internal)
      faked = Struct.new(:id, :name)
      @gallery_groups_data = data_internal.map do |old|
        faked.new(old['f1'], old['f2'])
      end
    else
      @gallery_groups_data = gallery_groups
    end
    @gallery_groups_data
  end

  def character_gallery_for(character)
    characters_galleries.find_by(character_id: character)
  end
end
