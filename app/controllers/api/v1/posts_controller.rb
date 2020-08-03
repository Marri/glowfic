class Api::V1::PostsController < Api::ApiController
  before_action :login_required, except: [:index, :show]
  before_action :find_post, only: [:show, :update]

  resource_description do
    description 'Viewing and editing posts'
  end

  api :GET, '/posts', 'Load all posts optionally filtered by subject'
  param :q, String, required: false, desc: 'Subject search term'
  def index
    queryset = Post.order(Arel.sql('LOWER(subject) asc'))
    queryset = queryset.where('LOWER(subject) LIKE ?', "%#{params[:q].downcase}%") if params[:q].present?

    posts = paginate queryset, per_page: 25
    posts = posts.visible_to(current_user)
    render json: {results: posts.as_json(min: true)}
  end

  api :GET, '/posts/:id', 'Load a single post as a JSON resource'
  param :id, :number, required: true, desc: "Post ID"
  error 403, "Post is not visible to the user"
  error 404, "Post not found"
  def show
    render json: @post.as_json
  end

  api :PATCH, '/posts/:id', 'Update a single post. Currently only supports saving the private note for an author.'
  header 'Authorization', 'Authorization token for a user in the format "Authorization" : "Bearer [token]"', required: true
  param :id, :number, required: true, desc: "Post ID"
  param :private_note, String, required: true, desc: "Author's private notes about this post"
  error 403, "Post is not visible to the user"
  error 404, "Post not found"
  error 422, "Invalid parameters provided"
  def update
    author = @post.author_for(current_user)
    unless author.present?
      access_denied
      return
    end

    unless author.update(private_note: params[:private_note])
      error = {message: 'Post could not be updated.'}
      render json: {errors: [error]}, status: :unprocessable_entity
      return
    end

    render json: {private_note: helpers.sanitize_written_content(params[:private_note])}
  end

  api :POST, '/posts/reorder', 'Update the order of posts. This is an unstable feature, and may be moved or renamed; it should not be trusted.'
  error 401, "You must be logged in"
  error 403, "Board is not editable by the user"
  error 404, "Post IDs could not be found"
  error 422, "Invalid parameters provided"
  param :ordered_post_ids, Array, allow_blank: false
  param :section_id, :number, required: false
  def reorder
    section_id = params[:section_id] ? params[:section_id].to_i : nil
    post_ids = params[:ordered_post_ids].map(&:to_i).uniq
    posts = Post.where(id: post_ids)
    posts_count = posts.count
    unless posts_count == post_ids.count
      missing_posts = post_ids - posts.pluck(:id)
      error = {message: "Some posts could not be found: #{missing_posts * ', '}"}
      render json: {errors: [error]}, status: :not_found and return
    end

    boards = Board.where(id: posts.select(:board_id).distinct.pluck(:board_id))
    unless boards.count == 1
      error = {message: 'Posts must be from one board'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    board = boards.first
    access_denied and return unless board.editable_by?(current_user)

    post_section_ids = posts.select(:section_id).distinct.pluck(:section_id)
    unless post_section_ids == [section_id] &&
      (section_id.nil? || BoardSection.where(id: section_id, board_id: board.id).exists?)
      error = {message: 'Posts must be from one specified section in the board, or no section'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    Post.transaction do
      posts = posts.sort_by {|post| post_ids.index(post.id) }
      posts.each_with_index do |post, index|
        next if post.section_order == index
        post.update(section_order: index)
      end

      other_posts = Post.where(board_id: board.id, section_id: section_id).where.not(id: post_ids).ordered_in_section
      other_posts.each_with_index do |post, i|
        index = i + posts_count
        next if post.section_order == index
        post.update(section_order: index)
      end
    end

    posts = Post.where(board_id: board.id, section_id: section_id)
    render json: {post_ids: posts.ordered_in_section.pluck(:id)}
  end

  private

  def find_post
    return unless (@post = find_object(Post))
    access_denied unless @post.visible_to?(current_user)
  end
end
