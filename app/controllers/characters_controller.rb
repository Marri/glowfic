# frozen_string_literal: true
class CharactersController < ApplicationController
  include Taggable
  include CharacterSplit

  before_action :login_required, except: [:index, :show, :facecasts, :search]
  before_action :find_model, only: [:show, :edit, :update, :duplicate, :destroy, :replace, :do_replace]
  before_action :find_group, only: :index
  before_action :require_permission, only: [:edit, :update, :duplicate, :replace, :do_replace]
  before_action :editor_setup, only: [:new, :edit]

  def index
    (return if login_required) unless params[:user_id].present?

    @user = if params[:user_id].present?
      User.active.find_by_id(params[:user_id])
    else
      current_user
    end

    unless @user
      flash[:error] = "User could not be found."
      redirect_to users_path and return
    end

    @page_title = if @user.id == current_user.try(:id)
      "Your Characters"
    else
      @user.username + "'s Characters"
    end
  end

  def new
    @page_title = 'New Character'
    @character = Character.new(template_id: params[:template_id], user: current_user)
    @character.build_template(user: current_user) unless @character.template
  end

  def create
    @character = Character.new(user: current_user)
    @character.assign_attributes(permitted_params)
    @character.settings = process_tags(Setting, obj_param: :character, id_param: :setting_ids)
    @character.gallery_groups = process_tags(GalleryGroup, obj_param: :character, id_param: :gallery_group_ids)
    build_template

    begin
      @character.save!
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@character, :create_failed)
      log_error(e) unless @character.errors.present?

      @page_title = "New Character"
      editor_setup
      render :new
    else
      flash[:success] = "Character created."
      redirect_to character_path(@character)
    end
  end

  def show
    @page_title = @character.name
    @posts = posts_from_relation(@character.recent_posts)
    @meta_og = og_data
    use_javascript('characters/show') if @character.user_id == current_user.try(:id)
  end

  def edit
    @page_title = 'Edit Character: ' + @character.name
  end

  def update
    begin
      Character.transaction do
        @character.assign_attributes(permitted_params)
        build_template

        if current_user.id != @character.user_id && @character.audit_comment.blank?
          flash[:error] = "You must provide a reason for your moderator edit."
          editor_setup
          render :edit and return
        end

        @character.settings = process_tags(Setting, obj_param: :character, id_param: :setting_ids)
        @character.gallery_groups = process_tags(GalleryGroup, obj_param: :character, id_param: :gallery_group_ids)
        @character.save!
      end
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@character, :update_failed)
      log_error(e) unless @character.errors.present?

      @page_title = "Edit Character: " + @character.name
      editor_setup
      render :edit
    else
      flash[:success] = "Character updated."
      redirect_to character_path(@character)
    end
  end

  def duplicate
    dupe = @character.dup

    begin
      Character.transaction do
        dupe.gallery_groups = @character.gallery_groups
        dupe.settings = @character.settings
        dupe.ungrouped_gallery_ids = @character.ungrouped_gallery_ids
        @character.aliases.find_each do |calias|
          dupalias = calias.dup
          dupe.aliases << dupalias
          dupalias.save!
        end
        dupe.save!
      end
    rescue ActiveRecord::RecordInvalid => e
      render_err(dupe, :duplicate_failed)
      log_error(e) unless dupe.errors.present?
      redirect_to character_path(@character)
    else
      flash[:success] = "Character duplicated. You are now editing the new character."
      redirect_to edit_character_path(dupe)
    end
  end

  def destroy
    unless @character.deletable_by?(current_user)
      flash[:error] = "You do not have permission to modify this character."
      redirect_to user_characters_path(current_user) and return
    end

    begin
      @character.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@character, :delete_failed)
      log_error(e) unless @character.errors.present?
      redirect_to character_path(@character)
    else
      flash[:success] = "Character deleted."
      redirect_to user_characters_path(current_user)
    end
  end

  def facecasts
    @page_title = 'Facecasts'
    chars = Character.where(users: {deleted: false}).where.not(pb: nil)
      .joins(:user)
      .left_outer_joins(:template)
      .pluck('characters.id, characters.name, characters.pb, users.id, users.username, templates.id, templates.name')
    @pbs = []

    pb_struct = Struct.new(:item_id, :item_name, :type, :pb, :user_id, :username)
    chars.each do |dataset|
      id, name, pb, user_id, username, template_id, nickname = dataset
      if template_id.present?
        item_id, item_name, type = template_id, nickname, Template
      else
        item_id, item_name, type = id, name, Character
      end
      @pbs << pb_struct.new(item_id, item_name, type, pb, user_id, username)
    end
    @pbs.uniq!

    if params[:sort] == "name"
      @pbs.sort_by! {|x| [x[:item_name].downcase, x[:pb].downcase, x[:username].downcase]}
    elsif params[:sort] == "writer"
      @pbs.sort_by! {|x| [x[:username].downcase, x[:pb].downcase, x[:item_name].downcase]}
    else
      @pbs.sort_by! {|x| [x[:pb].downcase, x[:username].downcase, x[:item_name].downcase]}
    end
  end

  def replace
    @page_title = 'Replace Character: ' + @character.name
    if @character.template
      @alts = @character.template.characters
    else
      @alts = @character.user.characters.where(template_id: nil)
    end
    @alts -= [@character] unless @alts.size <= 1 || @character.aliases.exists?
    use_javascript('icons')

    icons = @alts.map do |alt|
      if alt.default_icon.present?
        [alt.id, {url: alt.default_icon.url, keyword: alt.default_icon.keyword, aliases: alt.aliases.as_json}]
      else
        [alt.id, {url: view_context.image_path('icons/no-icon.png'), keyword: 'No Icon', aliases: alt.aliases.as_json}]
      end
    end
    gon.gallery = Hash[icons]
    gon.gallery[''] = {url: view_context.image_path('icons/no-icon.png'), keyword: 'No Character'}

    @alt_dropdown = @alts.map do |alt|
      name = alt.name
      name += ' | ' + alt.screenname if alt.screenname
      name += ' | ' + alt.nickname if alt.nickname
      name += ' | ' + alt.settings.pluck(:name).join(' & ') if alt.settings.present?
      [name, alt.id]
    end
    @alt = @alts.first

    reply_post_ids = Reply.where(character_id: @character.id).select(:post_id).distinct.pluck(:post_id)
    all_posts = Post.where(character_id: @character.id) + Post.where(id: reply_post_ids)
    @posts = all_posts.uniq
  end

  def do_replace
    unless params[:icon_dropdown].blank? || (new_char = Character.find_by_id(params[:icon_dropdown]))
      flash[:error] = "Character could not be found."
      redirect_to replace_character_path(@character) and return
    end

    if new_char && new_char.user_id != current_user.id
      flash[:error] = "You do not have permission to modify this character."
      redirect_to replace_character_path(@character) and return
    end

    orig_alias = nil
    if params[:orig_alias].present? && params[:orig_alias] != 'all'
      orig_alias = CharacterAlias.find_by_id(params[:orig_alias])
      unless orig_alias && orig_alias.character_id == @character.id
        flash[:error] = "Invalid old alias."
        redirect_to replace_character_path(@character) and return
      end
    end

    new_alias_id = nil
    if params[:alias_dropdown].present?
      new_alias = CharacterAlias.find_by_id(params[:alias_dropdown])
      unless new_alias && new_alias.character_id == new_char.try(:id)
        flash[:error] = "Invalid new alias."
        redirect_to replace_character_path(@character) and return
      end
      new_alias_id = new_alias.id
    end

    success_msg = ''
    wheres = {character_id: @character.id}
    updates = {character_id: new_char.try(:id), character_alias_id: new_alias_id}

    if params[:post_ids].present?
      wheres[:post_id] = params[:post_ids]
      success_msg = " in the specified " + 'post'.pluralize(params[:post_ids].size)
    end

    wheres[:character_alias_id] = orig_alias.try(:id) if @character.aliases.exists? && params[:orig_alias] != 'all'

    UpdateModelJob.perform_later(Reply.to_s, wheres, updates, current_user.id)
    wheres[:id] = wheres.delete(:post_id) if params[:post_ids].present?
    UpdateModelJob.perform_later(Post.to_s, wheres, updates, current_user.id)

    flash[:success] = "All uses of this character#{success_msg} will be replaced."
    redirect_to character_path(@character)
  end

  def search
    @page_title = 'Search Characters'
    use_javascript('posts/search')
    @users = []
    @templates = []
    return unless params[:commit].present?

    @search_results = Character.unscoped

    if params[:author_id].present?
      @users = User.active.where(id: params[:author_id])
      if @users.present?
        @search_results = @search_results.where(user_id: params[:author_id])
      else
        flash.now[:error] = "The specified author could not be found."
      end
    end

    if params[:template_id].present?
      @templates = Template.where(id: params[:template_id])
      template = @templates.first
      if template.present?
        if @users.present? && template.user_id != @users.first.id
          flash.now[:error] = "The specified author and template do not match; template filter will be ignored."
          @templates = []
        else
          @search_results = @search_results.where(template_id: params[:template_id])
        end
      else
        flash.now[:error] = "The specified template could not be found."
      end
    elsif params[:author_id].present?
      @templates = Template.where(user_id: params[:author_id]).ordered.limit(25)
    end

    if params[:name].present?
      where_calc = []
      where_calc << "name LIKE ?" if params[:search_name].present?
      where_calc << "screenname LIKE ?" if params[:search_screenname].present?
      where_calc << "nickname LIKE ?" if params[:search_nickname].present?

      @search_results = @search_results.where(where_calc.join(' OR '), *(['%' + params[:name].to_s + '%'] * where_calc.length))
    end

    @search_results = @search_results.ordered.paginate(page: page)
  end

  private

  def find_model
    unless (@character = Character.find_by_id(params[:id]))
      flash[:error] = "Character could not be found."
      if logged_in?
        redirect_to user_characters_path(current_user)
      else
        redirect_to root_path
      end
    end
  end

  def find_group
    return unless params[:group_id].present?
    @group = CharacterGroup.find_by_id(params[:group_id])
  end

  def require_permission
    unless @character.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this character."
      redirect_to user_characters_path(current_user) and return
    end
  end

  def editor_setup
    faked = Struct.new(:name, :id)
    user = @character.try(:user) || current_user
    @templates = user.templates.ordered
    new_group = faked.new('— Create New Group —', 0)
    @groups = user.character_groups.order('name asc') + [new_group]
    use_javascript('characters/editor')
    gon.character_id = @character.try(:id) || ''
    @character.build_template(user: user) if @character.present? && @character.template.nil? && @character.user == current_user
    gon.user_id = user.id
    @aliases = @character.aliases.ordered if @character
    gon.mod_editing = (user != current_user)
    groups = @character.try(:gallery_groups) || []
    gon.gallery_groups = groups.map {|group| group.as_json(include: [:gallery_ids], user_id: user.id) }
  end

  def build_template
    return unless params[:new_template].present?
    return unless @character.user == current_user
    @character.build_template unless @character.template
    @character.template.user = current_user
  end

  def og_data
    # User >> Template >> Character | screenname
    # Nickname(s): a, b. Settings: c, d
    # Description
    # n posts.

    character_desc = [@character.name, @character.screenname].select(&:present?).join(' | ')
    title = [character_desc]
    title.prepend(@character.template.name) if @character.template.present?
    title.prepend(@character.user.username) unless @character.user.deleted?

    linked = []
    nicknames = ([@character.nickname] + @character.aliases.pluck(:name)).uniq.compact
    linked << "Nickname".pluralize(nicknames.count) + ": " + nicknames.join(', ') if nicknames.present?
    settings = @character.settings.pluck(:name)
    linked << "Setting".pluralize(settings.count) + ": " + settings.join(', ') if settings.present?
    desc = [linked.join('. ')].reject(&:blank?)
    desc << generate_short(@character.description) if @character.description.present?
    reply_posts = Reply.where(character_id: @character.id).select(:post_id).distinct.pluck(:post_id)
    posts_count = Post.where(character_id: @character.id).or(Post.where(id: reply_posts)).privacy_public.uniq.count
    desc << "#{posts_count} #{'post'.pluralize(posts_count)}" if posts_count > 0
    data = {
      url: character_url(@character),
      title: title.join(' » '),
      description: desc.join("\n"),
    }
    if @character.default_icon.present?
      data[:image] = {
        src: @character.default_icon.url,
        width: '75',
        height: '75',
      }
    end
    data
  end

  def permitted_params
    permitted = [
      :name,
      :nickname,
      :screenname,
      :template_id,
      :pb,
      :description,
      :audit_comment,
      :retired,
      :cluster,
      ungrouped_gallery_ids: [],
    ]
    if @character.user == current_user
      permitted.last[:template_attributes] = [:name, :id]
      permitted.insert(0, :default_icon_id)
    end
    params.fetch(:character, {}).permit(permitted)
  end
end
