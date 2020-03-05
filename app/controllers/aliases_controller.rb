# frozen_string_literal: true
class AliasesController < GenericController
  prepend_before_action :find_character, :login_required
  before_action :require_create_permission, only: [:create, :new]

  def new
    @page_title = "New Alias: " + @character.name
    super
  end

  def create
    @page_title = "New Alias: " + @character.name
    @create_redirect = edit_character_path(@character)
    super
  end

  def destroy
    @dsm = "Alias removed."
    @destroy_redirect = @destroy_failure_redirect = edit_character_path(@character)
    super
  end

  private

  def find_character
    @character = find_parent(Character, id: params[:character_id], redirect: user_characters_path(current_user))
  end

  def require_create_permission
    unless @character.user == current_user
      flash[:error] = "You do not have permission to modify this character."
      redirect_to user_characters_path(current_user) and return
    end
  end
  alias_method :require_delete_permission, :require_create_permission

  def find_model
    unless (@alias = CharacterAlias.find_by(id: params[:id]))
      flash[:error] = "Alias could not be found."
      redirect_to edit_character_path(@character) and return
    end

    unless @alias.character_id == @character.id
      flash[:error] = "Alias could not be found for that character."
      redirect_to edit_character_path(@character) and return
    end

    @model = @alias
  end

  def permitted_params
    params.fetch(:character_alias, {}).permit(:name)
  end

  def set_params
    @alias.character = @character
  end

  def model_class
    CharacterAlias
  end
end
