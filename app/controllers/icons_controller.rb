# frozen_string_literal: true
class IconsController < UploadingController
  before_action(only: [:replace, :do_replace, :avatar, :delete_multiple]) { login_required }
  before_action(only: [:replace, :do_replace, :avatar]) { find_model }
  before_action(only: [:replace, :do_replace, :avatar]) { require_edit_permission }

  def delete_multiple
    gallery = Gallery.find_by_id(params[:gallery_id])
    icon_ids = (params[:marked_ids] || []).map(&:to_i).reject(&:zero?)
    if icon_ids.empty? || (icons = Icon.where(id: icon_ids)).empty?
      flash[:error] = "No icons selected."
      redirect_to user_galleries_path(current_user) and return
    end

    if params[:gallery_delete]
      unless gallery
        flash[:error] = "Gallery could not be found."
        redirect_to user_galleries_path(current_user) and return
      end

      unless gallery.user_id == current_user.id
        flash[:error] = "You do not have permission to modify this gallery."
        redirect_to user_galleries_path(current_user) and return
      end

      icons.each do |icon|
        next unless icon.user_id == current_user.id
        gallery.icons.destroy(icon)
      end

      flash[:success] = "Icons removed from gallery."
      icon_redirect(gallery) and return
    end

    icons.each do |icon|
      next unless icon.user_id == current_user.id
      icon.destroy
    end
    flash[:success] = "Icons deleted."
    icon_redirect(gallery) and return
  end

  def show
    @page_title = @icon.keyword
    if params[:view] == 'posts'
      post_ids = Reply.where(icon_id: @icon.id).select(:post_id).distinct.pluck(:post_id)
      posts = Post.where(icon_id: @icon.id).or(Post.where(id: post_ids))
      @posts = posts_from_relation(posts.ordered)
    elsif params[:view] == 'galleries'
      use_javascript('galleries/expander_old')
    else
      posts_using = Post.where(icon_id: @icon.id).visible_to(current_user)
      replies_using = Reply.where(icon_id: @icon.id).visible_to(current_user)
      @times_used = (posts_using.count + replies_using.count)
      @posts_used = (posts_using.pluck(:id) + replies_using.select(:post_id).distinct.pluck(:post_id)).uniq.count
    end
    @meta_og = og_data
  end

  def edit
    @page_title = 'Edit Icon: ' + @icon.keyword
    super
  end

  def update
    @page_title = 'Edit icon: ' + @icon.keyword
    super
  end

  def replace
    @page_title = "Replace Icon: " + @icon.keyword
    all_icons = if @icon.has_gallery?
      @icon.galleries.map(&:icons).flatten.uniq.compact - [@icon]
    else
      current_user.galleryless_icons - [@icon]
    end
    @alts = all_icons.sort_by{|i| i.keyword.downcase }
    use_javascript('icons')
    gon.gallery = Hash[all_icons.map { |i| [i.id, {url: i.url, keyword: i.keyword}] }]
    gon.gallery[''] = {url: view_context.image_path('icons/no-icon.png'), keyword: 'No Icon'}

    post_ids = Reply.where(icon_id: @icon.id).select(:post_id).distinct.pluck(:post_id)
    all_posts = Post.where(icon_id: @icon.id) + Post.where(id: post_ids)
    @posts = all_posts.uniq
  end

  def do_replace
    unless params[:icon_dropdown].blank? || (new_icon = Icon.find_by_id(params[:icon_dropdown]))
      flash[:error] = "Icon could not be found."
      redirect_to replace_icon_path(@icon) and return
    end

    if new_icon && new_icon.user_id != current_user.id
      flash[:error] = "You do not have permission to modify this icon."
      redirect_to replace_icon_path(@icon) and return
    end

    wheres = {icon_id: @icon.id}
    wheres[:post_id] = params[:post_ids] if params[:post_ids].present?
    UpdateModelJob.perform_later(Reply.to_s, wheres, {icon_id: new_icon.try(:id)})
    wheres[:id] = wheres.delete(:post_id) if params[:post_ids].present?
    UpdateModelJob.perform_later(Post.to_s, wheres, {icon_id: new_icon.try(:id)})

    flash[:success] = "All uses of this icon will be replaced."
    redirect_to icon_path(@icon)
  end

  def destroy
    gallery = @icon.galleries.first if @icon.galleries.count == 1
    @destroy_redirect = gallery ? gallery_path(gallery) : user_galleries_path(current_user)
    super
  end

  def avatar
    if current_user.update(avatar: @icon)
      flash[:success] = "Avatar set."
    else
      @icon.errors.merge!(current_user.errors)
      render_errors(@icon, action: 'set', class_name: 'Avatar')
    end
    redirect_to icon_path(@icon)
  end

  private

  def editor_setup
    if @icon.present?
      use_javascript('galleries/update_existing')
      use_javascript('galleries/uploader')
      set_s3_url
    end
  end

  def require_edit_permission
    if @icon.user_id != current_user.id
      flash[:error] = "You do not have permission to modify this icon."
      redirect_to user_galleries_path(current_user)
    end
  end

  def icon_redirect(gallery)
    if params[:return_to] == 'index'
      redirect_to user_galleries_path(current_user, anchor: "gallery-#{gallery.id}")
    elsif params[:return_tag].present? && (tag = Tag.find_by_id(params[:return_tag]))
      redirect_to tag_path(tag, anchor: "gallery-#{gallery.id}")
    elsif gallery
      redirect_to gallery_path(id: gallery.id)
    else
      redirect_to user_gallery_path(id: 0, user_id: current_user.id)
    end
  end

  def og_data
    galleries = @icon.galleries.pluck(:name)
    if galleries.present?
      desc = "Gallery".pluralize(galleries.count) + ": " + galleries.join(', ')
    else
      desc = "Galleryless"
    end
    desc += ". By #{@icon.credit}" if @icon.credit
    {
      url: icon_url(@icon),
      title: @icon.keyword,
      description: desc,
      image: {
        src: @icon.url,
        width: '75',
        height: '75',
      }
    }
  end

  def permitted_params
    params.fetch(:icon, {}).permit(:url, :keyword, :credit, :s3_key)
  end

  def invalid_redirect
    logged_in? ? user_galleries_path(current_user) : root_path
  end
end
