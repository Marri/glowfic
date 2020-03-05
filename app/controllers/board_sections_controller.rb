# frozen_string_literal: true
class BoardSectionsController < GenericController
  before_action(only: [:new, :create]) { require_edit_permission }

  def create
    board = Board.find_by(id: permitted_params[:board_id])
    @csm = "New section, #{permitted_params[:name]}, created for #{board.try(:name)}."
    @create_redirect = edit_board_path(board) if board.present?
    super
  end

  def show
    super
    @posts = posts_from_relation(@board_section.posts.ordered_in_section)
    @meta_og = og_data
  end

  def destroy
    @destroy_redirect = edit_board_path(@board_section.board)
    super
  end

  private

  def permitted_params
    params.fetch(:board_section, {}).permit(
      :board_id,
      :name,
      :description,
    )
  end

  def editor_setup
    if @board_section.present?
      use_javascript('board_sections')
      gon.section_id = @board_section.id
    end
  end

  def require_edit_permission
    board_id = permitted_params[:board_id] || params[:board_id]
    board = @board_section.try(:board) || Board.find_by(id: board_id)
    if board && !board.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this continuity."
      redirect_to boards_path and return
    end
  end
  alias_method :require_delete_permission, :require_edit_permission

  def og_data
    stats = []
    board = @board_section.board
    stats << board.writers.where.not(deleted: true).ordered.pluck(:username).join(', ') if board.authors_locked?
    post_count = @board_section.posts.where(privacy: Concealable::PUBLIC).count
    stats << "#{post_count} " + "post".pluralize(post_count)
    desc = [stats.join(' – ')]
    desc << generate_short(@board_section.description) if @board_section.description.present?
    {
      url: board_section_url(@board_section),
      title: "#{board.name} » #{@board_section.name}",
      description: desc.join("\n"),
    }
  end

  def model_name
    'Section'
  end

  def model_class
    BoardSection
  end

  def invalid_redirect
    boards_path
  end
end
