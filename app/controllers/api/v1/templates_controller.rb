class Api::V1::TemplatesController < Api::ApiController
  resource_description do
    description 'Viewing and searching templates'
  end

  api :GET, '/templates', 'Load all the templates that match the given query, results ordered by name'
  param :q, String, required: false, desc: "Query string"
  param :page, :number, required: false, desc: 'Page in results (25 per page)'
  param :user_id, :number, required: false, desc: 'ID of the template user (optional)'
  error 422, "Invalid parameters provided"
  def index
    queryset = Template.where("name LIKE ?", "#{params[:q]}%").ordered

    if params[:user_id].present?
      return unless find_object(User, param: :user_id, status: :unprocessable_entity)
      queryset = queryset.where(user_id: params[:user_id])
    end

    templates = paginate queryset, per_page: 25
    render json: {results: templates}
  end
end
