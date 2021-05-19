class Api::V1::TagsController < Api::ApiController
  before_action :find_tag, except: :index

  resource_description do
    description 'Viewing tags'
  end

  api :GET, '/tags', 'Load all the tags of the specified type that match the given query, results ordered by name'
  param :q, String, required: false, desc: "Query string"
  param :page, :number, required: false, desc: 'Page in results (25 per page)'
  param :tag_id, :number, required: false, desc: 'Used for settings so we don\'t show the current setting as a possible parent setting of itself'
  error 422, "Invalid parameters provided"
  def index
    type = find_type
    queryset = type.where("name LIKE ?", params[:q].to_s + '%').ordered_by_name

    queryset = queryset.where.not(id: params[:tag_id]) if params[:tag_id].present?

    tags = paginate queryset, per_page: 25
    render json: {results: tags}
  end

  api :GET, '/tags/:id', 'Load a single tag as a JSON resource'
  param :id, :number, required: true, desc: 'Tag ID'
  error 404, "Tag not found"
  def show
    render json: @setting.as_json(user_id: params[:user_id])
  end

  private

  def find_tag
    unless (@setting = Setting.find_by(id: params[:id]))
      error = {message: 'Tag could not be found'}
      render json: {errors: [error]}, status: :not_found and return
    end
  end
end
