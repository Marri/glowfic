# frozen_string_literal: true
class IndexSectionsController < GenericController
  before_action :find_index, only: [:new, :create]
  before_action(only: [:new, :create]) { require_edit_permission }

  def new
    super
  end

  def create
    section_name = params[:index_section].fetch(:name, nil)
    @csm = "New section, #{section_name}, created for #{@index.name}."
    @create_redirect = index_path(@index)
    super
  end

  def update
    @update_redirect = index_path(@section.index)
    super
  end

  def destroy
    @destroy_redirect = @destroy_failure_redirect = index_path(@section.index)
    super
  end

  private

  def find_index
    id = params[:index_id] || permitted_params[:index_id]
    @index = find_parent(Index, id: id, redirect: indexes_path)
  end

  def require_edit_permission
    index = @index || @section.index
    unless index.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this index."
      redirect_to index_path(index)
    end
  end
  alias_method :require_delete_permission, :require_edit_permission

  def permitted_params
    params.fetch(:index_section, {}).permit(:name, :description, :index_id)
  end

  def set_model
    @section = @model
  end

  def model_name
    'Index section'
  end

  def model_class
    IndexSection
  end

  def models_path
    indexes_path
  end
  alias_method :invalid_redirect, :models_path
end
