# frozen_string_literal: true
class TemplatesController < GenericController
  def show
    super
    @user = @template.user
    character_ids = @template.characters.pluck(:id)
    post_ids = Reply.where(character_id: character_ids).select(:post_id).distinct.pluck(:post_id)
    posts = Post.where(character_id: character_ids).or(Post.where(id: post_ids))
    @posts = posts_from_relation(posts.ordered)
    @meta_og = og_data
  end

  def destroy
    @destroy_redirect = user_characters_path(current_user)
    super
  end

  def search
  end

  private

  def editor_setup
    @selectable_characters = @template.try(:characters) || []
    @selectable_characters += current_user.characters.where(template_id: nil).ordered
    @selectable_characters.uniq!
    @character_ids = permitted_params[:character_ids] if permitted_params.key?(:character_ids)
    @character_ids ||= @template.try(:character_ids) || []
  end

  def require_edit_permission
    unless @template.user_id == current_user.id
      flash[:error] = "You do not have permission to modify this template."
      redirect_to user_characters_path(current_user)
    end
  end

  def set_params
    @template.user = current_user
  end

  def og_data
    desc = []
    character_count = @template.characters.count
    desc << generate_short(@template.description) if @template.description.present?
    desc << "#{character_count} " + "character".pluralize(character_count)
    title = [@template.name]
    title.prepend(@template.user.username) unless @template.user.deleted?
    {
      url: template_url(@template),
      title: title.join(' » '),
      description: desc.join("\n"),
    }
  end

  def permitted_params
    params.fetch(:template, {}).permit(:name, :description, character_ids: [])
  end

  def invalid_redirect
    logged_in? ? user_characters_path(current_user) : root_path
  end
end
