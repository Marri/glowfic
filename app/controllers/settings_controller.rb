# frozen_string_literal: true
class SettingsController < ApplicationController
  include Taggable

  before_action :login_required, except: [:index, :show]
  before_action :find_model, except: :index
  before_action :require_edit_permission, only: [:edit, :update]
  before_action :require_delete_permission, only: [:destroy]

  def index
    @settings = Setting::Searcher.new.search(name: params[:name], page: page)
    @post_counts = Post.visible_to(current_user).joins(setting_posts: :setting).where(setting_posts: {setting_id: @settings.map(&:id)})
    @post_counts = @post_counts.group('setting_posts.setting_id').count
    @page_title = 'Settings'
    use_javascript('tags/index')
  end

  def show
    @page_title = @setting.name.to_s
    @view = params[:view]
    @meta_og = og_data
    @tag = @setting

    if @view == 'posts'
      @posts = posts_from_relation(@setting.posts.ordered)
    elsif @view == 'characters'
      @characters = @setting.characters.includes(:user, :template).ordered.paginate(page: page)
    elsif @view != 'settings'
      @view = 'info'
    end
  end

  def edit
    @page_title = "Edit Setting: #{@setting.name}"
    build_editor
  end

  def update
    @setting.assign_attributes(permitted_params)

    begin
      Setting.transaction do
        @setting.parent_settings = process_tags(Setting, obj_param: :setting, id_param: :parent_setting_ids)
        @setting.save!
      end
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        message: "Setting could not be saved because of the following problems:",
        array: @setting.errors.full_messages
      }
      @page_title = "Edit Setting: #{@setting.name}"
      build_editor
      render :edit
    else
      flash[:success] = "Setting saved!"
      redirect_to setting_path(@setting)
    end
  end

  def destroy
    if @setting.destroy
      flash[:success] = "Setting deleted."

      url_params = {}
      url_params[:page] = page if params[:page].present?
      url_params[:view] = params[:view] if params[:view].present?
      redirect_to settings_path(url_params)
    else
      flash[:error] = {
        message: "Setting could not be deleted.",
        array: @setting.errors.full_messages
      }
      redirect_to setting_path(@setting)
    end
  end

  private

  def find_model
    unless (@setting = Setting.find_by_id(params[:id]))
      flash[:error] = "Setting could not be found."
      redirect_to settings_path
    end
  end

  def require_edit_permission
    unless @setting.editable_by?(current_user)
      flash[:error] = "You do not have permission to edit this setting."
      redirect_to setting_path(@setting)
    end
  end

  def require_delete_permission
    unless @setting.deletable_by?(current_user)
      flash[:error] = "You do not have permission to edit this setting."
      redirect_to setting_path(@setting)
    end
  end

  def build_editor
    return unless @setting.is_a?(Setting)
    use_javascript('tags/edit')
  end

  def og_data
    desc = []
    desc << generate_short(@setting.description) if @setting.description.present?
    stats = []
    post_count = @setting.posts.privacy_public.count
    stats << "#{post_count} " + "post".pluralize(post_count) if post_count > 0
    character_count = @setting.characters.count
    stats << "#{character_count} " + "character".pluralize(character_count) if character_count > 0
    desc << stats.join(', ')
    title = [@setting.name]
    title << @setting.user.username if @setting.owned? && !@setting.user.deleted?
    title << 'Setting'
    {
      url: setting_url(@setting),
      title: title.join(' · '),
      description: desc.join("\n"),
    }
  end

  def permitted_params
    permitted = [:type, :description, :owned]
    permitted.insert(0, :name, :user_id) if current_user.admin? || @setting.user == current_user
    params.fetch(:setting, {}).permit(permitted)
  end
end
