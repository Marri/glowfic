# frozen_string_literal: true
class AliasesController < ApplicationController
  before_action :login_required
  before_action :find_character
  before_action :find_model, only: :destroy

  def new
    @page_title = "New Alias: " + @character.name
    @alias = CharacterAlias.new(character: @character)
  end

  def create
    @alias = CharacterAlias.new(permitted_params)
    @alias.character = @character

    begin
      @alias.save!
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@alias, :create_failed)
      log_error(e) unless @alias.errors.present?

      @page_title = "New Alias: " + @character.name
      render :new
    else
      flash[:success] = "Alias created."
      redirect_to edit_character_path(@character)
    end
  end

  def destroy
    begin
      @alias.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@alias, :delete_failed)
      log_error(e) unless @alias.errors.present?
    else
      flash[:success] = "Alias removed."
    end
    redirect_to edit_character_path(@character)
  end

  private

  def find_character
    unless (@character = Character.find_by_id(params[:character_id]))
      flash[:error] = "Character could not be found."
      redirect_to user_characters_path(current_user) and return
    end

    unless @character.user == current_user
      flash[:error] = "You do not have permission to modify this character."
      redirect_to user_characters_path(current_user) and return
    end
  end

  def find_model
    unless (@alias = CharacterAlias.find_by_id(params[:id]))
      flash[:error] = "Alias could not be found."
      redirect_to edit_character_path(@character) and return
    end

    unless @alias.character_id == @character.id
      flash[:error] = "Alias could not be found for that character."
      redirect_to edit_character_path(@character) and return
    end
  end

  def permitted_params
    params.fetch(:character_alias, {}).permit(:name)
  end
end
