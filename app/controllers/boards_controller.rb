# frozen_string_literal: true
class BoardsController < GenericController
  before_action(only: [:mark]) { login_required }

  def index
    if params[:user_id].present?
      unless (@user = User.active.find_by_id(params[:user_id]))
        flash[:error] = "User could not be found."
        redirect_to root_path and return
      end

      @page_title = if @user.id == current_user.try(:id)
        "Your Continuities"
      else
        @user.username + "'s Continuities"
      end

      board_ids = BoardAuthor.where(user_id: @user.id, cameo: false).select(:board_id).distinct.pluck(:board_id)
      @boards = Board.where(creator_id: @user.id).or(Board.where(id: board_ids)).ordered
      @cameo_boards = Board.where(id: BoardAuthor.where(user_id: @user.id, cameo: true).select(:board_id).distinct.pluck(:board_id)).ordered
    else
      @page_title = 'Continuities'
      @boards = Board.ordered.paginate(page: page, per_page: 25)
    end
  end

  def show
    super
    @board_sections = @board.board_sections.ordered
    board_posts = @board.posts.where(section_id: nil)
    if @board.ordered?
      board_posts = board_posts.ordered_in_section
    else
      board_posts = board_posts.ordered
    end
    @posts = posts_from_relation(board_posts, no_tests: false)
    @meta_og = og_data
    use_javascript('boards/show')
  end

  def edit
    super
    use_javascript('boards/edit')
    @unsectioned_posts = @board.posts.where(section_id: nil).ordered_in_section if @board.ordered?
  end

  def update
    super
  end

  def mark
    unless (board = Board.find_by_id(params[:board_id]))
      flash[:error] = "Continuity could not be found."
      redirect_to unread_posts_path and return
    end

    if params[:commit] == "Mark Read"
      Board.transaction do
        board.mark_read(current_user)
        read_time = board.last_read(current_user)
        post_views = PostView.joins(post: :board).where(user: current_user, boards: {id: board.id})
        post_views.update_all(read_at: read_time, updated_at: read_time) # rubocop:disable Rails/SkipsModelValidations
      end
      flash[:success] = "#{board.name} marked as read."
    elsif params[:commit] == "Hide from Unread"
      board.ignore(current_user)
      flash[:success] = "#{board.name} hidden from this page."
    else
      flash[:error] = "Please choose a valid action."
    end
    redirect_to unread_posts_path
  end

  def search
    @page_title = 'Search Continuities'
    @users = User.active.where(id: params[:author_id]).ordered if params[:author_id].present?
    return unless params[:commit].present?

    searcher = Board::Searcher.new
    @search_results = searcher.search(params, page: page)
  end

  private

  def editor_setup
    @coauthors = @cameos = User.active.ordered
    if @board
      @coauthors -= @board.cameos
      @cameos -= @board.writers
      @coauthors -= [@board.creator]
      @cameos -= [@board.creator]
      @board_sections = @board.board_sections.ordered
    else
      @coauthors -= [current_user]
      @cameos -= [current_user]
    end
    use_javascript('boards/editor')
  end

  def og_data
    metadata = []
    metadata << @board.writers.where.not(deleted: true).ordered.pluck(:username).join(', ') if @board.authors_locked?
    post_count = @board.posts.where(privacy: Concealable::PUBLIC).count
    stats = "#{post_count} " + "post".pluralize(post_count)
    section_count = @board.board_sections.count
    stats += " in #{section_count} " + "section".pluralize(section_count) if section_count > 0
    metadata << stats
    desc = [metadata.join(' – ')]
    desc << generate_short(@board.description) if @board.description.present?
    {
      url: board_url(@board),
      title: @board.name,
      description: desc.join("\n"),
    }
  end

  def permitted_params
    params.fetch(:board, {}).permit(:name, :description, coauthor_ids: [], cameo_ids: [])
  end

  def set_params
    @board.creator = current_user
  end

  def model_name
    'Continuity'
  end

  def model_class
    Board
  end
end
