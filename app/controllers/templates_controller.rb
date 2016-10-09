class TemplatesController < ApplicationController
  before_filter :login_required, except: [:index, :show]
  before_filter :find_template, :only => [:show, :destroy, :edit, :update]
  before_filter :require_own_template, :only => [:edit, :update, :destroy]

  def index
    @page_title = "Your Templates"
    @user = current_user
    if params[:user_id].present?
      @user = User.find_by_id(params[:user_id]) || current_user
      @page_title = @user.username + "'s Templates"
    end

    unless @user
      flash[:error] = "User could not be found."
      redirect_to users_path and return
    end
    @templates = @user.templates
  end

  def new
    @template = Template.new
  end

  def create
    @template = Template.new(params[:template])
    @template.user = current_user
    if @template.save
      flash[:success] = "Template saved successfully."
      redirect_to template_path(@template)
    else
      flash.now[:error] = "Your template could not be saved."
      render :action => :new
    end
  end

  def show
    @user = @template.user
    @characters = @template.characters
    character_ids = @characters.map(&:id)
    post_ids = Reply.where(character_id: character_ids).select(:post_id).map(&:post_id).uniq
    where = Post.where(character_id: character_ids).where(id: post_ids).where_values.reduce(:or)
    @posts = Post.where(where).order('tagged_at desc').paginate(per_page: 25, page: page)
  end

  def edit
  end

  def update
    if @template.update_attributes(params[:template])
      flash[:success] = "Template saved successfully."
      redirect_to template_path(@template)
    else
      flash.now[:error] = "Your template could not be saved."
      render :action => :edit
    end
  end

  def destroy
    @template.destroy
    flash[:success] = "Template deleted successfully."
    redirect_to templates_path
  end

  private

  def find_template
    unless @template = Template.find_by_id(params[:id])
      flash[:error] = "Template could not be found."
      redirect_to templates_path and return
    end
  end

  def require_own_template
    return true if @template.user_id == current_user.id
    flash[:error] = "That is not your template."
    redirect_to templates_path
  end
end
