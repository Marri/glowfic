# frozen_string_literal: true
class IndexPostsController < ApplicationController
  before_action :login_required
  before_action :find_index_post, only: [:edit, :update, :destroy]

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
    @index_post = IndexPost.new(index_params)

    if @index_post.index && !@index_post.index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(@index_post.index) and return
    end

    unless @index_post.save
      render_errors(@index_post, now: true, action: 'added', msg: 'Post could not be added to index')
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
    unless @index_post.update(index_params)
      render_errors(@index_post, action: 'updated', now: true, class_name: 'Index')
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
      render_errors(@index_post, action: 'removed', msg: 'Post could not be removed from index')
      log_error(e) unless @index_post.errors.present?
    else
      flash[:success] = "Post removed from index."
    end
    redirect_to index_path(@index_post.index)
  end

  private

  def index_params
    params.fetch(:index_post, {}).permit(:description, :index_id, :index_section_id, :post_id)
  end

  def find_index_post
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
