# class must declare permitted_params to use
# frozen_string_literal: true
class GenericController < ApplicationController
  before_action :login_required, only: [:new, :create, :edit, :update, :destroy]
  before_action :find_model, only: [:show, :edit, :update, :destroy]
  before_action :editor_setup, only: [:new, :edit]
  before_action :require_view_permission, only: [:show, :edit, :update, :destroy]
  before_action :require_edit_permission, only: [:edit, :update]
  before_action :require_delete_permission, only: :destroy

  def index
    @page_title = controller_name.titlecase
  end

  def new
    @page_title ||= "New #{model_name.titlecase}"
    @model = model_class.new
    set_model
    set_params
  end

  def create
    @model = model_class.new(permitted_params)
    set_model
    set_params

    begin
      @model.save!
    rescue ActiveRecord::RecordInvalid => e
      render_errors(@model, action: 'created', now: true, class_name: model_name.capitalize, msg: @cfm)
      log_error(e) unless @model.errors.present?
      @page_title ||= "New #{model_name.titlecase}"
      set_model
      editor_setup
      render :new
    else
      flash[:success] = @csm || "#{model_name} created."
      redirect_to @create_redirect || model_path(@model)
    end
  end

  def show
    @page_title = @model.name.to_s
  end

  def edit
    @page_title = "Edit #{model_name.titlecase}" + (@model.has_attribute?(:name) ? ": #{@model.name}" : "")
  end

  def update
    begin
      @model.update!(permitted_params)
    rescue ActiveRecord::RecordInvalid => e
      render_errors(@model, action: 'updated', now: true, class_name: model_name.capitalize, msg: @ufm)
      log_error(e) unless @model.errors.present?
      @page_title ||= "Edit #{model_name.titlecase}" + (@model.has_attribute?(:name) ? ": #{@model.name}" : "")
      render :edit
    else
      flash[:success] = @usm || "#{model_name} updated."
      redirect_to @update_redirect || model_path(@model)
    end
  end

  def destroy
    begin
      @model.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_errors(@model, action: 'deleted', class_name: model_name.capitalize, msg: @dfm)
      log_error(e) unless @model.errors.present?
      redirect_to @destroy_failure_redirect || model_path(@model)
    else
      flash[:success] = @dsm || "#{model_name} deleted."
      redirect_to @destroy_redirect || models_path
    end
  end

  protected

  def find_model
    unless (@model = model_class.find_by_id(params[:id]))
      flash[:error] = "#{model_name} could not be found."
      redirect_to invalid_redirect and return
    end
    set_model
  end

  def find_parent(model, id:, redirect:)
    if (parent = model.find_by(id: id))
      parent
    else
      flash[:error] = "#{model} could not be found."
      redirect_to redirect
    end
  end

  def require_view_permission
    return unless model_class.method_defined? :visible_to?
    unless @model.visible_to?(current_user)
      flash[:error] = "You do not have permission to view this #{model_name.downcase}."
      redirect_to unviewable_redirect
    end
  end

  def require_edit_permission
    return unless model_class.method_defined? :editable_by?
    unless @model.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this #{model_name.downcase}."
      redirect_to uneditable_redirect
    end
  end

  def require_delete_permission
    unless model_class.method_defined? :deletable_by?
      require_edit_permission
      return
    end

    unless @model.deletable_by?(current_user)
      flash[:error] = "You do not have permission to modify this #{model_name.downcase}."
      redirect_to uneditable_redirect
    end
  end

  def model_name
    @mn ||= controller_name.classify
  end

  def model_class
    @mc ||= model_name.constantize
  end

  def model_path(model=@model)
    send("#{controller_name.singularize}_path", model)
  end
  alias_method :uneditable_redirect, :model_path

  def models_path
    @msp ||= send("#{controller_name}_path")
  end
  alias_method :invalid_redirect, :models_path
  alias_method :unviewable_redirect, :models_path

  def set_model
    instance_variable_set("@#{controller_name.singularize}", @model)
  end

  def editor_setup
    # pass
  end

  def set_params
    # pass
  end
end
