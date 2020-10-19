# frozen_string_literal: true
class IndexPostsController < ApplicationController
  before_action :login_required
  before_action :find_model, only: [:edit, :update, :destroy]

  def new
    unless (index = Index.find_by_id(params[:index_id]))
      flash[:error] = "Index could not be found."
      redirect_to indexes_path and return
    end

    unless index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(index) and return
    end

    @index_post = IndexPost.new(index: index, index_section_id: params[:index_section_id])
    @page_title = "Add Posts to Index"
    use_javascript('posts/index_post_new')
  end

  def create
    @index_post = IndexPost.new(permitted_params)

    if @index_post.index && !@index_post.index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(@index_post.index) and return
    end

    unless @index_post.save
      render_err.now(@index_post, :create_failed)
      @page_title = 'Add Posts to Index'
      use_javascript('posts/index_post_new')
      render :new and return
    end

    flash[:success] = "Post added to index."
    redirect_to index_path(@index_post.index)
  end

  def edit
    @page_title = "Edit Post in Index"
  end

  def update
    unless @index_post.update(permitted_params)
      render_err.now(@index_post, :update_failed)
      @page_title = "Edit Post in Index"
      render action: :edit and return
    end

    flash[:success] = "Index post updated."
    redirect_to index_path(@index_post.index)
  end

  def destroy
    begin
      @index_post.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@index_post, :delete_failed)
      log_error(e) unless @index_post.errors.present?
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

    unless @index_post.index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(@index_post.index) and return
    end
  end
end
