class Character::Replacer < Generic::Replacer
  attr_reader :alt_dropdown

  def initialize(character)
    @character = character
    super()
  end

  def setup(no_icon_url)
    super
    @alt_dropdown = construct_dropdown
  end

  def replace(params, user:)
    new_char = check_target(params[:icon_dropdown], user: user)
    return if @errors.present?

    orig_alias = check_alias(params[:orig_alias], state: 'old') unless params[:orig_alias] == 'all'
    new_alias = check_alias(params[:alias_dropdown], character: new_char, state: 'new')
    return if @errors.present?

    wheres = setup_wheres(params, orig_alias.presence)
    updates = setup_updates(new_char, new_alias)

    replace_jobs(wheres: wheres, updates: updates, post_ids: params[:post_ids])
  end

  private

  def find_alts
    if @character.template
      alts = @character.template.characters
    else
      alts = @character.user.characters.where(template_id: nil)
    end
    alts -= [@character] unless alts.size <= 1 || @character.aliases.exists?
    alts
  end

  def construct_gallery(no_icon_url)
    icons = @alts.map do |alt|
      if alt.default_icon.present?
        [alt.id, {url: alt.default_icon.url, keyword: alt.default_icon.keyword, aliases: alt.aliases.as_json}]
      else
        [alt.id, {url: no_icon_url, keyword: 'No Icon', aliases: alt.aliases.as_json}]
      end
    end
    gallery = Hash[icons]
    gallery[''] = {url: no_icon_url, keyword: 'No Character'}
    gallery
  end

  def construct_dropdown
    @alts.map do |alt|
      name = [alt.name]
      name << alt.try(:screenname)
      name << alt.try(:template_name)
      name << alt.settings.pluck(:name).join(' & ') if alt.settings.present?
      [name.reject(&:nil?).join(' | '), alt.id]
    end
  end

  def find_posts
    super({character_id: @character.id})
  end

  def check_target(id, user:)
    super(Character, id: id, user: user)
  end

  def check_alias(alias_id, character: @character, state:)
    if alias_id.present?
      alias_obj = CharacterAlias.find_by(id: alias_id)
      @errors.add(:base, "Invalid #{state} alias.") unless alias_obj && alias_obj.character_id == character.id
      alias_obj
    end
  end

  def setup_wheres(params, orig_alias)
    wheres = {character_id: @character.id}
    wheres[:post_id] = params[:post_ids] if params[:post_ids].present?
    wheres[:character_alias_id] = orig_alias if @character.aliases.exists? && params[:orig_alias] != 'all'
    wheres
  end

  def setup_updates(new_char, new_alias)
    updates = {character_id: new_char.try(:id)}
    updates[:character_alias_id] = new_alias.id if new_alias.present?
    updates
  end
end
