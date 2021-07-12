# frozen_string_literal: true
class NewsController < ApplicationController
  before_action :login_required, except: [:index, :show]
  before_action :find_model, only: [:show, :edit, :update, :destroy]
  before_action :require_create_permission, only: [:new, :create]
  before_action :require_edit_permission, only: [:edit, :update]

  def index
    @page_title = 'Site News'
    @news = News.order(id: :desc).paginate(page: page, per_page: 1)
    @news.first&.mark_read(current_user) if logged_in?
  end

  def new
    @page_title = 'Create News Post'
    @news = News.new
  end

  def create
    @news = News.new(permitted_params)
    @news.user = current_user

    begin
      @news.save!
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        message: "News post could not be created.",
        array: @news.errors.full_messages
      }
      @page_title = 'Create News Post'
      render :new
    else
      flash[:success] = "News post has successfully been created."
      redirect_to news_index_path
    end
  end

  def show
    @meta_og = og_data
    redirect_to paged_news_url(@news)
  end

  def edit
    @page_title = 'Edit News Post'
  end

  def update
    begin
      @news.update!(permitted_params)
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        message: "News post could not be saved because of the following problems:",
        array: @news.errors.full_messages
      }
      @page_title = "Edit News Post"
      render :edit
    else
      flash[:success] = "News post saved!"
      redirect_to paged_news_url(@news)
    end
  end

  def destroy
    unless @news.deletable_by?(current_user)
      flash[:error] = "You do not have permission to edit that news post."
      redirect_to news_index_path and return
    end

    begin
      @news.destroy!
    rescue ActiveRecord::RecordNotDestroyed
      flash[:error] = {
        message: "News post could not be deleted.",
        array: @news.errors.full_messages
      }
    else
      flash[:success] = "News post deleted."
    end
    redirect_to news_index_path
  end

  private

  def find_model
    unless (@news = News.find_by_id(params[:id]))
      flash[:error] = "News post could not be found."
      redirect_to news_index_path and return
    end
  end

  def require_create_permission
    unless current_user.has_permission?(:create_news)
      flash[:error] = "You do not have permission to manage news posts."
      redirect_to news_index_path and return
    end
  end

  def require_edit_permission
    unless @news.editable_by?(current_user)
      flash[:error] = "You do not have permission to edit that news post."
      redirect_to news_index_path and return
    end
  end

  def permitted_params
    params.fetch(:news, {}).permit(:content)
  end

  def paged_news_url(news)
    page_num = News.where('id >= ?', news.id).count
    page_num = nil unless page_num > 1
    news_index_path(page: page_num)
  end

  def og_data
    {
      url: paged_news_url(@news),
      title: "News Post for #{@news.created_at.strftime('%b %d, %Y')}",
      description: generate_short(@news.content),
    }
  end
end
