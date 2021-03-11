class Api::V1::CharactersController < Api::ApiController
  before_action :login_required, only: [:update, :reorder]
  before_action :find_character, except: [:index, :reorder]
  before_action :find_post, except: [:update, :reorder]
  before_action :find_template, only: :index
  before_action :find_user, only: :index
  before_action :require_permission, only: :update

  resource_description do
    description 'Viewing and editing characters'
  end

  api :GET, '/characters', 'Load all the characters that match the given query, results ordered by name'
  param :q, String, required: false, desc: "If provided, will return only characters where q is present as a substring anywhere in any of a character's name, screenname or template nickname."
  param :page, :number, required: false, desc: 'Page in results (25 per page)'
  param :post_id, :number, required: false, desc: 'If provided, will return only characters that appear in the provided post'
  param :user_id, :number, required: false, desc: 'If provided, will return only characters that belong to the provided user'
  param :template_id, :number, required: false, desc: 'If provided, will return only characters that belong to the provided template. Use 0 to find only characters with no template.'
  param :includes, Array, in: ["default_icon", "aliases", "nickname"], of: String, required: false, desc: 'Specify additional fields to return in JSON'
  error 403, "Post is not visible to the user"
  error 422, "Invalid parameters provided"
  def index
    queryset = Character.ordered
    queryset = queryset.with_name(params[:q].to_s) if params[:q].present?
    queryset = queryset.where(user_id: @user.id) if params[:user_id].present?
    queryset = queryset.where(template_id: @template&.id) if params[:template_id].present?

    if @post
      char_ids = @post.replies.select(:character_id).distinct.pluck(:character_id) + [@post.character_id]
      queryset = queryset.where(id: char_ids)
    end

    characters = paginate queryset, per_page: 25
    includes = [:selector_name] + (params[:includes] || []).map(&:to_sym)
    render json: {results: characters.as_json(include: includes)}
  end

  api :GET, '/characters/:id', 'Load a single character as a JSON resource'
  param :id, :number, required: true, desc: 'Character ID'
  param :post_id, :number, required: false, desc: 'If provided, will return an additional alias_id_for_post param to represent most recently used alias for this character in the provided post'
  error 403, "Post is not visible to the user"
  error 404, "Character not found"
  error 422, "Invalid parameters provided"
  def show
    render json: @character.as_json(include: [:galleries, :default_icon, :aliases], post_for_alias: @post)
  end

  api :PATCH, '/characters/:id', 'Update a given character'
  param :id, :number, required: true, desc: 'Character ID'
  error 401, "You must be logged in"
  error 403, "Character is not editable by the user"
  error 404, "Character not found"
  error 422, "Invalid parameters provided"
  def update
    render json: {data: @character.as_json(include: [:default_icon])} and return unless params[:character]

    errors = []
    if params[:character][:default_icon_id].present?
      errors << {message: "Default icon could not be found"} unless Icon.find_by_id(params[:character][:default_icon_id])
    end

    @character.assign_attributes(character_params)
    errors += @character.errors.full_messages.map { |msg| {message: msg} } unless @character.valid?
    render json: {errors: errors}, status: :unprocessable_entity and return unless errors.empty?

    @character.save!
    render json: @character.as_json(include: [:default_icon])
  end

  api :POST, '/characters/reorder', 'Update the order of galleries on a character. This is an unstable feature, and may be moved or renamed; it should not be trusted.'
  error 401, "You must be logged in"
  error 403, "Character is not editable by the user"
  error 404, "CharactersGallery IDs could not be found"
  error 422, "Invalid parameters provided"
  param :ordered_characters_gallery_ids, Array, allow_blank: false
  def reorder
    section_ids = params[:ordered_characters_gallery_ids].map(&:to_i).uniq
    sections = CharactersGallery.where(id: section_ids)
    sections_count = sections.count
    unless sections_count == section_ids.count
      missing_sections = section_ids - sections.pluck(:id)
      error = {message: "Some character galleries could not be found: #{missing_sections * ', '}"}
      render json: {errors: [error]}, status: :not_found and return
    end

    characters = Character.where(id: sections.select(:character_id).distinct.pluck(:character_id))
    unless characters.count == 1
      error = {message: 'Character galleries must be from one character'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    character = characters.first
    access_denied and return unless character.editable_by?(current_user)

    CharactersGallery.transaction do
      sections = sections.sort_by {|section| section_ids.index(section.id) }
      sections.each_with_index do |section, index|
        next if section.section_order == index
        section.update(section_order: index)
      end

      other_sections = CharactersGallery.where(character_id: character.id).where.not(id: section_ids).ordered
      other_sections.each_with_index do |section, i|
        index = i + sections_count
        next if section.section_order == index
        section.update(section_order: index)
      end
    end

    render json: {characters_gallery_ids: CharactersGallery.where(character_id: character.id).ordered.pluck(:id)}
  end

  private

  def find_character
    @character = find_object(Character)
  end

  def find_post
    return unless params[:post_id].present?
    return unless (@post = find_object(Post, param: :post_id, status: :unprocessable_entity))
    access_denied unless @post.visible_to?(current_user)
  end

  def find_template
    return unless params[:template_id].present?
    # filter for templateless characters, so @template should remain nil without find_object raising a missing template error
    return if params[:template_id] == '0'
    @template = find_object(Template, param: :template_id, status: :unprocessable_entity)
  end

  def find_user
    return unless params[:user_id].present?
    @user = find_object(User, param: :user_id, status: :unprocessable_entity)
  end

  def require_permission
    access_denied unless @character.user == current_user
  end

  def character_params
    params.fetch(:character, {}).permit(:default_icon_id, :name, :nickname, :screenname, :setting, :template_id, :pb, :description, gallery_ids: [])
  end
end
