# frozen_string_literal: true
class IndexPostsController < ApplicationController
  before_action :login_required
  before_action :find_model, only: [:edit, :update, :destroy]
  before_action :find_index, only: [:new, :create]
  before_action :require_edit_permission, only: [:edit, :update, :destroy]
  before_action :require_create_permission, only: [:new, :create]

  def new
    @index_post = IndexPost.new(index: @index, index_section_id: params[:index_section_id])
    @page_title = "Add Posts to Index"
    use_javascript('posts/index_post_new')
  end

  def create
    @index_post = IndexPost.new(permitted_params)

    unless @index_post.save
      flash.now[:error] = {
        message: "Post could not be added to index.",
        array: @index_post.errors.full_messages
      }
      @page_title = 'Add Posts to Index'
      use_javascript('posts/index_post_new')
      render :new and return
    end

    flash[:success] = "Post added to index!"
    redirect_to index_path(@index_post.index)
  end

  def edit
    @page_title = "Edit Post in Index"
  end

  def update
    unless @index_post.update(permitted_params)
      flash.now[:error] = {}
      flash.now[:error][:message] = "Index could not be saved"
      flash.now[:error][:array] = @index_post.errors.full_messages
      @page_title = "Edit Post in Index"
      render action: :edit and return
    end

    flash[:success] = "Index post has been updated."
    redirect_to index_path(@index_post.index)
  end

  def destroy
    begin
      @index_post.destroy!
    rescue ActiveRecord::RecordNotDestroyed
      flash[:error] = {
        message: "Post could not be removed from index.",
        array: @index_post.errors.full_messages
      }
    else
      flash[:success] = "Post removed from index."
    end
    redirect_to index_path(@index_post.index)
  end

  private

  def permitted_params
    params.fetch(:index_post, {}).permit(:description, :index_id, :index_section_id, :post_id)
  end

  def find_model
    unless (@index_post = IndexPost.find_by_id(params[:id]))
      flash[:error] = "Index post could not be found."
      redirect_to indexes_path and return
    end
  end

  def find_index
    id = params[:index_id] || permitted_params[:index_id]
    unless (@index = Index.find_by(id: id))
      flash[:error] = "Index could not be found."
      redirect_to indexes_path and return
    end
  end

  def require_create_permission
    unless @index.editable_by?(current_user)
      flash[:error] = "You do not have permission to edit this index."
      redirect_to index_path(@index) and return
    end
  end

  def require_edit_permission
    unless @index_post.index.editable_by?(current_user)
      flash[:error] = "You do not have permission to edit this index."
      redirect_to index_path(@index_post.index) and return
    end
  end
end
