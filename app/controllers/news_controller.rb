# frozen_string_literal: true
class NewsController < ApplicationController
  before_action :login_required, except: [:index, :show]
  before_action :require_staff, except: [:index, :show]
  before_action :find_model, only: [:show, :edit, :update, :destroy]
  before_action :require_permission, only: [:edit, :update]

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
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@news, :create_failed)
      log_error(e) unless @news.errors.present?

      @page_title = 'Create News Post'
      render :new
    else
      flash[:success] = "News post created."
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
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@news, :update_failed)
      log_error(e) unless @news.errors.present?

      @page_title = "Edit News Post"
      render :edit
    else
      flash[:success] = "News post updated."
      redirect_to paged_news_url(@news)
    end
  end

  def destroy
    unless @news.deletable_by?(current_user)
      flash[:error] = "You do not have permission to modify this news post."
      redirect_to news_index_path and return
    end

    begin
      @news.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@news, :delete_failed)
      log_error(e) unless @news.errors.present?
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

  def require_staff
    unless current_user.admin? || current_user.mod?
      flash[:error] = "You do not have permission to manage news posts."
      redirect_to news_index_path and return
    end
  end

  def require_permission
    unless @news.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this news post."
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
