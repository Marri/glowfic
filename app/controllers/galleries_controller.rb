# frozen_string_literal: true
class GalleriesController < UploadingController
  include Taggable

  before_action :login_required, except: [:index, :show]
  before_action :find_gallery, only: [:destroy, :edit, :update] # assumes login_required
  before_action :setup_new_icons, only: [:add, :icon]
  before_action :set_s3_url, only: [:edit, :add, :icon]
  before_action :setup_editor, only: [:new, :edit]

  def index
    if params[:user_id].present?
      unless (@user = User.active.find_by_id(params[:user_id]))
        flash[:error] = 'User could not be found.'
        redirect_to root_path and return
      end
    else
      return if login_required
      @user = current_user
    end

    @page_title = if @user.id == current_user.try(:id)
      "Your Galleries"
    else
      @user.username + "'s Galleries"
    end
    use_javascript('galleries/expander')
    gon.user_id = @user.id
  end

  def new
    @page_title = 'New Gallery'
    @gallery = Gallery.new
  end

  def create
    @gallery = Gallery.new(gallery_params)
    @gallery.user = current_user
    @gallery.gallery_groups = process_tags(GalleryGroup, :gallery, :gallery_group_ids)

    begin
      @gallery.save!
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        message: "Your gallery could not be saved because of the following problems:",
        array: @gallery.errors.full_messages
      }
      @page_title = 'New Gallery'
      setup_editor
      render :new
    else
      flash[:success] = "Gallery saved successfully."
      redirect_to gallery_path(@gallery)
    end
  end

  def add
    if params[:id] == '0' && params[:type] == 'existing'
      flash[:error] = 'Cannot add existing icons to galleryless. Please remove from existing galleries instead.'
      redirect_to user_gallery_path(id: 0, user_id: current_user.id)
    end
  end

  def show
    if params[:id].to_s == '0' # avoids casting nils to 0
      if params[:user_id].present?
        unless (@user = User.active.find_by_id(params[:user_id]))
          flash[:error] = 'User could not be found.'
          redirect_to root_path and return
        end
      else
        return if login_required
        @user = current_user
      end
      @page_title = 'Galleryless Icons'
    else
      @gallery = Gallery.find_by_id(params[:id])
      unless @gallery
        flash[:error] = "Gallery could not be found."
        if logged_in?
          redirect_to user_galleries_path(current_user) and return
        else
          redirect_to root_path and return
        end
      end

      @user = @gallery.user
      @page_title = @gallery.name + ' (Gallery)'
      @meta_og = og_data
    end
    icons = @gallery ? @gallery.icons : @user.galleryless_icons
    render :show, locals: { icons: icons }
  end

  def edit
    @page_title = 'Edit Gallery: ' + @gallery.name
    use_javascript('galleries/uploader')
    use_javascript('galleries/edit')
  end

  def update
    @gallery.assign_attributes(gallery_params)

    begin
      Gallery.transaction do
        @gallery.gallery_groups = process_tags(GalleryGroup, :gallery, :gallery_group_ids)
        @gallery.save!
      end
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {}
      flash.now[:error][:message] = "Gallery could not be saved."
      flash.now[:error][:array] = @gallery.errors.full_messages
      @page_title = 'Edit Gallery: ' + @gallery.name_was
      use_javascript('galleries/uploader')
      use_javascript('galleries/edit')
      setup_editor
      set_s3_url
      render :edit
    else
      flash[:success] = "Gallery saved."
      redirect_to edit_gallery_path(@gallery)
    end
  end

  def icon
    adder = Gallery::IconAdder.new(@gallery, user: current_user, params: params)

    if params[:image_ids].present?
      adder.assign_existing
    else
      adder.create_new
    end
    @icons = adder.icons
    if adder.errors.present?
      error = adder.errors.full_messages.first
      if adder.icon_errors.present?
        flash[:error] = {
          message: error,
          array: adder.icon_errors
        }
      else
        flash[:error] = error
      end
      if @gallery.nil? && params[:image_ids].present?
        redirect_to user_galleries_path(current_user)
      else
        render :add
      end
    else
      flash[:success] = adder.success_message
      if @gallery
        redirect_to gallery_path(@gallery)
      else
        redirect_to user_gallery_path(id: 0, user_id: current_user.id)
      end
    end
  end

  def destroy
    begin
      @gallery.destroy!
    rescue ActiveRecord::RecordNotDestroyed
      flash[:error] = {}
      flash[:error][:message] = "Gallery could not be deleted."
      flash[:error][:array] = @gallery.errors.full_messages
      redirect_to gallery_path(@gallery)
    else
      flash[:success] = "Gallery deleted successfully."
      redirect_to user_galleries_path(current_user)
    end
  end

  def search
  end

  private

  def find_gallery
    @gallery = Gallery.find_by_id(params[:id])

    unless @gallery
      flash[:error] = "Gallery could not be found."
      redirect_to user_galleries_path(current_user) and return
    end

    unless @gallery.user_id == current_user.id
      flash[:error] = "That is not your gallery."
      redirect_to user_galleries_path(current_user) and return
    end
  end

  def setup_new_icons
    if params[:type] == "existing"
      use_javascript('galleries/add_existing')
    else
      use_javascript('galleries/add_new')
      use_javascript('galleries/uploader')
    end
    @icons = []
    find_gallery unless params[:id] == '0'
    @unassigned = current_user.galleryless_icons
    @page_title = "Add Icons"
    @page_title += ": " + @gallery.name unless @gallery.nil?
  end

  def setup_editor
    use_javascript('galleries/editor')
    gon.user_id = current_user.id
  end

  def og_data
    icon_count = @gallery.icons.count
    desc = ["#{icon_count} " + "icon".pluralize(icon_count)]
    tags = @gallery.gallery_groups_data.pluck(:name)
    tag_count = tags.count
    desc << "Tag".pluralize(tag_count) + ": " + generate_short(tags.join(', ')) if tag_count > 0
    title = [@gallery.name]
    title.prepend(@gallery.user.username) unless @gallery.user.deleted?
    {
      url: gallery_url(@gallery),
      title: title.join(' » '),
      description: desc.join("\n"),
    }
  end

  def gallery_params
    params.fetch(:gallery, {}).permit(
      :name,
      galleries_icons_attributes: [
        :id,
        :_destroy,
        icon_attributes: [:url, :keyword, :credit, :id, :_destroy, :s3_key]
      ],
      icon_ids: [],
    )
  end

  def icon_params(paramset)
    paramset.permit(:url, :keyword, :credit, :s3_key)
  end
end
