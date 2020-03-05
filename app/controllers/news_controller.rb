# frozen_string_literal: true
class NewsController < GenericController
  prepend_before_action :require_staff, :login_required, only: [:new, :create, :edit, :update, :destroy]

  def index
    @page_title = 'Site News'
    @news = News.order(id: :desc).paginate(page: page, per_page: 1)
    @news.first&.mark_read(current_user) if logged_in?
  end

  def new
    @page_title = 'Create News Post'
    super
  end

  def create
    @page_title = 'Create News Post'
    @create_redirect = news_index_path
    super
  end

  def show
    @meta_og = og_data
    redirect_to paged_news_url(@news)
  end

  def update
    @update_redirect = paged_news_url(@news)
    super
  end

  def destroy
    @destroy_redirect = @destroy_failure_redirect = news_index_path
    super
  end

  private

  def model_name
    'News post'
  end

  def model_class
    News
  end

  def set_params
    @news.user = current_user
  end

  def model_path
    paged_news_url(@news)
  end
  alias_method :update_redirect, :model_path

  def models_path
    news_index_path
  end
  alias_method :invalid_redirect, :models_path
  alias_method :uneditable_redirect, :models_path

  def require_staff
    unless current_user.admin? || current_user.mod?
      flash[:error] = "You do not have permission to manage news posts."
      redirect_to news_index_path
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
