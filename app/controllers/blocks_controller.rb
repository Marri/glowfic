class BlocksController < ApplicationController
  before_action :login_required
  before_action :find_model, only: [:edit, :update, :destroy]
  before_action :require_permission, only: [:edit, :update, :destroy]
  before_action :editor_setup, only: [:new, :edit]

  def index
    @page_title = "Blocked Users"
    @blocks = Block.where(blocking_user: current_user)
  end

  def new
    @page_title = "Block User"
    @block = Block.new
    @block.blocking_user = current_user
    @block.blocked_user_id = params.fetch(:block, {})[:blocked_user_id]
    @users = [@block.blocked_user].compact
  end

  def create
    @block = Block.new(permitted_params)
    @block.blocking_user = current_user
    @block.blocked_user_id = params.fetch(:block, {})[:blocked_user_id]

    begin
      @block.save!
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@block, :create_failed)
      log_error(e) unless @block.errors.present?
      editor_setup
      @users = [@block.blocked_user].compact
      @page_title = 'Block User'
      render :new
    else
      flash[:success] = "User blocked."
      redirect_to blocks_path
    end
  end

  def edit
    @page_title = 'Edit Block: ' + @block.blocked_user.username
  end

  def update
    begin
      @block.update!(permitted_params)
    rescue ActiveRecord::RecordInvalid => e
      render_err.now(@block, :update_failed)
      log_error(e) unless @block.errors.present?

      editor_setup
      @page_title = 'Edit Block: ' + @block.blocked_user.username
      render :edit
    else
      flash[:success] = "Block updated."
      redirect_to blocks_path
    end
  end

  def destroy
    begin
      @block.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      render_err(@block, :delete_failed)
      log_error(e) unless @block.errors.present?
    else
      flash[:success] = "User unblocked."
    end
    redirect_to blocks_path
  end

  private

  def permitted_params
    params.fetch(:block, {}).permit(:block_interactions, :hide_me, :hide_them)
  end

  def require_permission
    unless @block.editable_by?(current_user)
      flash[:error] = "Block could not be found." # Return the same error message as if it didn't exist
      redirect_to blocks_path and return
    end
  end

  def find_model
    unless (@block = Block.find_by(id: params[:id]))
      flash[:error] = "Block could not be found."
      redirect_to blocks_path and return
    end
  end

  def editor_setup
    use_javascript('blocks')
    @options = {
      "Nothing"    => :none,
      "Just posts" => :posts,
      "Everything" => :all,
    }
  end
end
