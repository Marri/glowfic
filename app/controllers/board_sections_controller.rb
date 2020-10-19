# frozen_string_literal: true
class BoardSectionsController < ApplicationController
  before_action :login_required, except: :show
  before_action :find_model, except: [:new, :create]
  before_action :require_permission, except: [:show, :update]

  def new
    @board_section = BoardSection.new(board_id: params[:board_id])
    @page_title = 'New Section'
  end

  def create
    @board_section = BoardSection.new(permitted_params)
    unless @board_section.board.nil? || @board_section.board.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this continuity."
      redirect_to continuities_path and return
    end

    begin
      @board_section.save!
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@board_section, :create_failed)
      log_error(e) unless @board_section.errors.present?

      @page_title = 'New Section'
      render :new
    else
      flash[:success] = "New section, #{@board_section.name}, created for #{@board_section.board.name}."
      redirect_to edit_continuity_path(@board_section.board)
    end
  end

  def show
    @page_title = @board_section.name
    @posts = posts_from_relation(@board_section.posts.ordered_in_section)
    @meta_og = og_data
  end

  def edit
    @page_title = 'Edit ' + @board_section.name
    use_javascript('board_sections')
    gon.section_id = @board_section.id
  end

  def update
    @board_section.assign_attributes(permitted_params)
    require_permission
    return if performed?

    begin
      @board_section.save!
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@board_section, :update_failed)
      log_error(e) unless @board_section.errors.present?

      @page_title = 'Edit ' + @board_section.name_was
      use_javascript('board_sections')
      gon.section_id = @board_section.id
      render :edit
    else
      flash[:success] = "Section updated."
      redirect_to board_section_path(@board_section)
    end
  end

  def destroy
    begin
      @board_section.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@board_section, :delete_failed)
      log_error(e) unless @board_section.errors.present?
      redirect_to board_section_path(@board_section)
    else
      flash[:success] = "Section deleted."
      redirect_to edit_continuity_path(@board_section.board)
    end
  end

  private

  def find_model
    @board_section = BoardSection.find_by_id(params[:id])
    unless @board_section
      flash[:error] = "Section not found."
      redirect_to continuities_path and return
    end
  end

  def require_permission
    board = @board_section.try(:board) || Board.find_by_id(params[:board_id])
    if board && !board.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this continuity."
      redirect_to continuities_path and return
    end
  end

  def og_data
    stats = []
    board = @board_section.board
    stats << board.writers.where.not(deleted: true).ordered.pluck(:username).join(', ') if board.authors_locked?
    post_count = @board_section.posts.privacy_public.count
    stats << "#{post_count} " + "post".pluralize(post_count)
    desc = [stats.join(' – ')]
    desc << generate_short(@board_section.description) if @board_section.description.present?
    {
      url: board_section_url(@board_section),
      title: "#{board.name} » #{@board_section.name}",
      description: desc.join("\n"),
    }
  end

  def permitted_params
    params.fetch(:board_section, {}).permit(
      :board_id,
      :name,
      :description,
    )
  end
end
