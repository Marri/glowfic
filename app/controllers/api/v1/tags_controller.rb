class Api::V1::TagsController < Api::ApiController
  before_action :find_tag, except: :index

  resource_description do
    description 'Viewing tags'
  end

  api :GET, '/tags', 'Load all the tags of the specified type that match the given query, results ordered by name'
  param :q, String, required: false, desc: "Query string"
  param :page, :number, required: false, desc: 'Page in results (25 per page)'
  param :t, Tag::TYPES, required: true, desc: 'Type of the tag to search'
  param :user_id, :number, required: false, desc: 'Filter GalleryGroups to the current user'
  param :tag_id, :number, required: false, desc: 'Used for settings so we don\'t show the current setting as a possible parent setting of itself'
  error 422, "Invalid parameters provided"
  def index
    type = find_type
    queryset = type.where("name LIKE ?", "#{params[:q]}%").ordered_by_name

    # gallery groups only searches groups the specified user has used
    if (user_id = params[:user_id]) && type == GalleryGroup
      user_gal_tags = GalleryGroup.joins(gallery_tags: [:gallery]).where(galleries: {user_id: user_id}).pluck(:id)
      user_char_tags = GalleryGroup.joins(character_tags: [:character]).where(characters: {user_id: user_id}).pluck(:id)
      queryset = queryset.where(id: user_gal_tags + user_char_tags)
    end

    queryset = queryset.where.not(id: params[:tag_id]) if type == Setting && params[:tag_id].present?

    tags = paginate queryset, per_page: 25
    render json: {results: tags}
  end

  api :GET, '/tags/:id', 'Load a single tag as a JSON resource'
  param :id, :number, required: true, desc: 'Tag ID'
  error 404, "Tag not found"
  def show
    render json: @tag.as_json(include: [:gallery_ids], user_id: params[:user_id])
  end

  private

  def find_tag
    unless (@tag = Tag.find_by(id: params[:id]))
      error = {message: 'Tag could not be found'}
      render json: {errors: [error]}, status: :not_found and return
    end
    @tag = find_type(@tag.type).find_by(id: params[:id])
  end

  def find_type(type_string=nil)
    type_string ||= params[:t]
    Tag::TYPES.detect {|x| x == type_string }.constantize
  end
end
