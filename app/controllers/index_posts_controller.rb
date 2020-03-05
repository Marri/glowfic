# frozen_string_literal: true
class IndexPostsController < GenericController
  before_action :find_index, only: [:new, :create]
  before_action(only: [:new, :create]) { require_edit_permission }

  def new
    @index_post = IndexPost.new(index: @index, index_section_id: params[:index_section_id])
    @page_title = "Add Posts to Index"
  end

  def create
    @csm = "Post added to index."
    @cfm = "Post could not be added to index"
    @create_redirect = index_path(@index)
    super
  end

  def edit
    @page_title = "Edit Post in Index"
  end

  def update
    @update_redirect = index_path(@index_post.index)
    @ufm = "Index could not be updated"
    @page_title = "Edit Post in Index"
    super
  end

  def destroy
    @dsm = "Post removed from index."
    @dfm = "Post could not be removed from index"
    @destroy_redirect = @destroy_failure_redirect = index_path(@index_post.index)
    super
  end

  private

  def find_index
    id = params[:index_id] || permitted_params[:index_id]
    @index = find_parent(Index, id: id, redirect: indexes_path)
  end

  def permitted_params
    params.fetch(:index_post, {}).permit(:description, :index_id, :index_section_id, :post_id)
  end

  def require_edit_permission
    index = @index || @index_post.index
    unless index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(index)
    end
  end
  alias_method :require_destroy_permission, :require_edit_permission

  def editor_setup
    use_javascript('posts/index_post_new')
  end

  def model_name
    'Index post'
  end

  def model_class
    IndexPost
  end

  def set_model
    @index_post = @model
  end

  def models_path
    indexes_path
  end
  alias_method :invalid_redirect, :models_path
end
