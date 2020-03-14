# frozen_string_literal: true
class IndexesController < ApplicationController
  before_action :login_required, except: [:index, :show]
  before_action :find_index, except: [:index, :new, :create]
  before_action :permission_required, except: [:index, :new, :create, :show]
  before_action :prepare_editor, only: :edit

  def index
    @page_title = "Indexes"
    @indexes = Index.order('id asc').paginate(per_page: 25, page: page)
  end

  def new
    @page_title = "New Index"
    @index = Index.new(user: current_user)
  end

  def create
    @index = Index.new(index_params)
    @index.user = current_user

    begin
      @index.save!
    rescue ActiveRecord::RecordInvalid => e
      render_errors(@index, action: 'created', now: true)
      log_error(e) unless @index.errors.present?

      @page_title = 'New Index'
      render :new
    else
      flash[:success] = "Index created!"
      redirect_to index_path(@index) and return
    end
  end

  def show
    unless @index.visible_to?(current_user)
      flash[:error] = "You do not have permission to view this index."
      redirect_to indexes_path and return
    end

    @page_title = @index.name.to_s
    @sectionless = @index.posts.where(index_posts: {index_section_id: nil})
    @sectionless = @sectionless.ordered_by_index
    dbselect = ', index_posts.description as index_description, index_posts.id as index_post_id'
    @sectionless = posts_from_relation(@sectionless, with_pagination: false, select: dbselect)
  end

  def edit
  end

  def update
    begin
      @index.update!(index_params)
    rescue ActiveRecord::RecordInvalid => e
      render_errors(@index, action: 'updated', now: true)
      log_error(e) unless @index.errors.present?

      prepare_editor
      render :edit
    else
      flash[:success] = "Index updated."
      redirect_to index_path(@index)
    end
  end

  def destroy
    begin
      @index.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_errors(@index, action: 'deleted')
      log_error(e) unless @index.errors.present?
      redirect_to index_path(@index)
    else
      redirect_to indexes_path
      flash[:success] = "Index deleted."
    end
  end

  private

  def find_index
    unless (@index = Index.find_by_id(params[:id]))
      flash[:error] = "Index could not be found."
      redirect_to indexes_path
    end
  end

  def permission_required
    unless @index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(@index)
    end
  end

  def index_params
    params.fetch(:index, {}).permit(:name, :description, :privacy, :authors_locked)
  end

  def prepare_editor
    @page_title = "Edit Index: #{@index.name}"
    use_javascript('posts/index_edit')
    @index_sections = @index.index_sections.ordered
    @unsectioned_posts = @index.posts.where(index_posts: {index_section_id: nil})
    @unsectioned_posts = @unsectioned_posts.select("posts.*, index_posts.id as index_post_id, index_posts.section_order as section_order")
    @unsectioned_posts = @unsectioned_posts.order('index_posts.section_order ASC')
  end
end
