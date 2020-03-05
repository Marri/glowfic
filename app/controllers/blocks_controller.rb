class BlocksController < GenericController
  before_action(only: [:index]) { login_required }

  def index
    @page_title = "Blocked Users"
    @blocks = Block.where(blocking_user: current_user)
  end

  def new
    @page_title = "Block User"
    @users = []
    super
  end

  def create
    @csm = "User blocked."
    @cfm = "User could not be blocked"
    @users = [User.find_by(id: params.fetch(:block, {})[:blocked_user_id])].compact
    @create_redirect = blocks_path
    super
  end

  def edit
    @page_title = 'Edit Block: ' + @block.blocked_user.username
  end

  def update
    @page_title = 'Edit Block: ' + @block.blocked_user.username
    @update_redirect = blocks_path
    super
  end

  def destroy
    @dsm = "User unblocked."
    @dfm = "User could not be unblocked"
    @destroy_failure_redirect = blocks_path
    super
  end

  private

  def permitted_params
    params.fetch(:block, {}).permit(:block_interactions, :hide_me, :hide_them)
  end

  def require_edit_permission
    unless @block.editable_by?(current_user)
      flash[:error] = "Block could not be found." # Return the same error message as if it didn't exist
      redirect_to blocks_path and return
    end
  end

  def set_params
    @block.blocking_user = current_user
    @block.blocked_user_id = params.fetch(:block, {})[:blocked_user_id]
  end

  def editor_setup
    use_javascript('blocks')
    @options = {
      "Nothing"    => Block::NONE,
      "Just posts" => Block::POSTS,
      "Everything" => Block::ALL,
    }
  end
end
