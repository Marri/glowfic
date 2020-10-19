# frozen_string_literal: true
class BoardsController < ApplicationController
  before_action :login_required, except: [:index, :show, :search]
  before_action :find_model, only: [:show, :edit, :update, :destroy]
  before_action :editor_setup, only: [:new, :edit]
  before_action :require_permission, only: [:edit, :update, :destroy]

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
      @boards = Board.ordered.paginate(page: page)
    end
  end

  def new
    @board = Board.new
    @board.creator = current_user
    @page_title = 'New Continuity'
  end

  def create
    @board = Board.new(permitted_params)
    @board.creator = current_user

    begin
      @board.save!
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@board, :create_failed)
      log_error(e) unless @board.errors.present?

      @page_title = 'New Continuity'
      editor_setup
      render :new
    else
      flash[:success] = "Continuity created."
      redirect_to continuities_path
    end
  end

  def show
    @page_title = @board.name
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
    @page_title = 'Edit Continuity: ' + @board.name
    use_javascript('boards/edit')
    @board_sections = @board.board_sections.ordered
    @unsectioned_posts = @board.posts.where(section_id: nil).ordered_in_section if @board.ordered?
  end

  def update
    begin
      @board.update!(permitted_params)
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@board, :update_failed)
      log_error(e) unless @board.errors.present?

      @page_title = 'Edit Continuity: ' + @board.name_was
      editor_setup
      use_javascript('board_sections')
      @board_sections = @board.board_sections.ordered
      render :edit
    else
      flash[:success] = "Continuity updated."
      redirect_to continuity_path(@board)
    end
  end

  def destroy
    begin
      @board.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@board, :delete_failed)
      log_error(e) unless @board.errors.present?
      redirect_to continuity_path(@board)
    else
      flash[:success] = "Continuity deleted."
      redirect_to continuities_path
    end
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
        post_views = Post::View.joins(post: :board).where(user: current_user, boards: {id: board.id})
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
    else
      @coauthors -= [current_user]
      @cameos -= [current_user]
    end
    use_javascript('boards/editor')
  end

  def find_model
    unless (@board = Board.find_by_id(params[:id]))
      flash[:error] = "Continuity could not be found."
      redirect_to continuities_path and return
    end
  end

  def require_permission
    unless @board.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this continuity."
      redirect_to continuity_path(@board) and return
    end
  end

  def og_data
    metadata = []
    metadata << @board.writers.where.not(deleted: true).ordered.pluck(:username).join(', ') if @board.authors_locked?
    post_count = @board.posts.privacy_public.count
    stats = "#{post_count} " + "post".pluralize(post_count)
    section_count = @board.board_sections.count
    stats += " in #{section_count} " + "section".pluralize(section_count) if section_count > 0
    metadata << stats
    desc = [metadata.join(' – ')]
    desc << generate_short(@board.description) if @board.description.present?
    {
      url: continuity_url(@board),
      title: @board.name,
      description: desc.join("\n"),
    }
  end

  def permitted_params
    params.fetch(:board, {}).permit(:name, :description, coauthor_ids: [], cameo_ids: [])
  end
end
