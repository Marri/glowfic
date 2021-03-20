class Api::V1::BoardsController < Api::ApiController
  resource_description do
    name 'Continuities'
    description 'Viewing, searching, and editing continuities'
  end

  api :GET, '/boards', 'Load all the continuities that match the given query, results ordered by name'
  param :q, String, required: false, desc: "Query string"
  param :page, :number, required: false, desc: 'Page in results (25 per page)'
  error 422, "Invalid parameters provided"
  def index
    queryset = Board.where("name LIKE ?", "#{params[:q]}%").ordered
    boards = paginate queryset, per_page: 25
    render json: {results: boards}
  end

  api :GET, '/boards/:id', 'Load a single continuity as a JSON resource.'
  param :id, :number, required: true, desc: 'Continuity ID'
  error 404, "Continuity not found"
  def show
    unless (board = Board.find_by_id(params[:id]))
      error = {message: "Continuity could not be found."}
      render json: {errors: [error]}, status: :not_found and return
    end

    render json: board.as_json(include: [:board_sections])
  end

  api :GET, '/boards/:id/posts', 'Load all posts in the specified continuity'
  param :id, :number, required: true, desc: "Continuity ID"
  param :page, :number, required: false, desc: 'Page in results (25 per page)'
  error 404, "Continuity not found"
  def posts
    unless (board = Board.find_by_id(params[:id]))
      error = {message: "Continuity could not be found."}
      render json: {errors: [error]}, status: :not_found and return
    end

    queryset = Post.privacy_public.where(board_id: board.id).with_reply_count.select('posts.*')
    posts = paginate queryset.includes(:board, :joined_authors, :section), per_page: 25
    render json: {results: posts}
  end
end
