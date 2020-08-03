class CharacterPresenter
  attr_reader :character

  def initialize(character)
    @character = character
  end

  def as_json(options={})
    return {} unless character

    char_json = character.as_json_without_presenter(only: [:id, :name, :screenname])
    return char_json unless options[:include].present? || options[:post_for_alias].present?

    if options[:post_for_alias].present?
      post = options[:post_for_alias]
      most_recent_use = post.replies.where(character_id: @character.id).ordered.last
      char_json[:alias_id_for_post] = most_recent_use.try(:character_alias_id)
      return char_json unless options[:include].present?
    end

    char_json[:selector_name] = character.selector_name if options[:include].include?(:selector_name)
    char_json[:default_icon] = character.default_icon.try(:as_json) if options[:include].include?(:default_icon)
    char_json[:aliases] = character.aliases if options[:include].include?(:aliases)
    char_json[:nickname] = character.nickname if options[:include].include?(:nickname)
    return char_json unless options[:include].include?(:galleries)

    galleries = if character.galleries.present? && character.user.icon_picker_grouping?
      multi_gallery_json
    else
      single_gallery_json
    end
    char_json.merge(galleries: galleries)
  end

  def multi_gallery_json
    galleries = character.galleries.ordered
    galleries.map do |gallery|
      {
        name: gallery.name,
        icons: gallery.icons
      }
    end
  end

  def single_gallery_json
    icons = character.icons
    icons |= [character.default_icon] if character.default_icon.present?
    return [] unless icons.present?
    [{icons: icons}]
  end
end
