# frozen_string_literal: true
class PostsController < WritableController
  include Taggable

  before_action :login_required, except: [:index, :show, :history, :warnings, :search, :stats]
  before_action :find_model, only: [:show, :history, :delete_history, :stats, :warnings, :edit, :update, :destroy]
  before_action :require_permission, only: [:edit, :delete_history]
  before_action :require_import_permission, only: [:new, :create]
  before_action :editor_setup, only: [:new, :edit]

  def index
    @posts = posts_from_relation(Post.ordered, show_blocked: !!params[:show_blocked])
    @page_title = 'Recent Threads'
  end

  def owed
    @show_unread = true
    @hide_quicklinks = true
    @page_title = 'Replies Owed'

    can_owe = (params[:view] != 'hidden')
    ids = Post::Author.where(user_id: current_user.id, can_owe: can_owe).group(:post_id).pluck(:post_id)
    @posts = Post.where(id: ids)
    unless params[:view] == 'hidden'
      drafts = ReplyDraft.where(post_id: @posts.select(:id)).where(user: current_user).pluck(:post_id)
      solo = Post::Author.where(post_id: ids).group(:post_id).having('count(post_id) < 2').pluck(:post_id)
      @posts = @posts.where.not(last_user: current_user).or(@posts.where(id: (drafts + solo).uniq))
    end
    @posts = @posts.where.not(status: [:complete, :abandoned])
    hiatused = @posts.hiatus.or(@posts.where('tagged_at < ?', 1.month.ago))

    if params[:view] == 'hiatused'
      @posts = hiatused
    elsif current_user.hide_hiatused_tags_owed?
      @posts = @posts.where.not(status: :hiatus).where('tagged_at > ?', 1.month.ago)
      @hiatused_exist = true if hiatused.count > 0
    end

    @posts = posts_from_relation(@posts.ordered)
  end

  def unread
    @started = (params[:started] == 'true') || (params[:started].nil? && current_user.unread_opened)
    @posts = Post.joins("LEFT JOIN post_views ON post_views.post_id = posts.id AND post_views.user_id = #{current_user.id}")
    @posts = @posts.joins("LEFT JOIN board_views on board_views.board_id = posts.board_id AND board_views.user_id = #{current_user.id}")
    @posts = @posts.where.not(post_views: {read_at: nil}) if @started

    # post view does not exist and (board view does not exist or post has updated since non-ignored board view read_at)
    no_post_view = @posts.where(post_views: { user_id: nil })
    updated_since_board_read = no_post_view.where(board_views: { read_at: nil })
      .or(no_post_view.where("date_trunc('second', board_views.read_at) < date_trunc('second', posts.tagged_at)"))
      .where(board_views: { ignored: false })
    no_post_view = no_post_view.where(board_views: { user_id: nil }).or(updated_since_board_read)

    # post view exists and post has updated since non-ignored post view read_at and (board view does not exist or is not ignored)
    with_post_view = @posts.where(post_views: { ignored: false }) # non-existant post-views will return nil here
    with_post_view = with_post_view.where(board_views: { user_id: nil}).or(with_post_view.where(board_views: { ignored: false }))
    with_post_view = with_post_view.where(post_views: { read_at: nil })
      .or(with_post_view.where("date_trunc('second', post_views.read_at) < date_trunc('second', posts.tagged_at)"))

    @posts = with_post_view.or(no_post_view)
    @posts = posts_from_relation(@posts.ordered, with_unread: true, show_blocked: !!params[:show_blocked])

    @hide_quicklinks = true
    @page_title = @started ? 'Opened Threads' : 'Unread Threads'
    use_javascript('posts/unread')
  end

  def mark
    posts = Post.where(id: params[:marked_ids])
    posts = posts.visible_to(current_user)

    if params[:commit] == "Mark Read"
      posts.each { |post| post.mark_read(current_user) }
      flash[:success] = "#{posts.size} #{'post'.pluralize(posts.size)} marked as read."
    elsif params[:commit] == "Remove from Replies Owed"
      posts.each { |post| post.opt_out_of_owed(current_user) }
      flash[:success] = "#{posts.size} #{'post'.pluralize(posts.size)} removed from replies owed."
      redirect_to owed_posts_path and return
    elsif params[:commit] == "Show in Replies Owed"
      posts.each { |post| post.opt_in_to_owed(current_user) }
      flash[:success] = "#{posts.size} #{'post'.pluralize(posts.size)} added to replies owed."
      redirect_to owed_posts_path and return
    else
      posts.each { |post| post.ignore(current_user) }
      flash[:success] = "#{posts.size} #{'post'.pluralize(posts.size)} hidden from this page."
    end
    redirect_to unread_posts_path
  end

  def hidden
    @hidden_boardviews = BoardView.where(user_id: current_user.id).where(ignored: true).includes(:board)
    hidden_post_ids = Post::View.where(user_id: current_user.id).where(ignored: true).select(:post_id).distinct.pluck(:post_id)
    @hidden_posts = posts_from_relation(Post.where(id: hidden_post_ids).ordered)
    @page_title = 'Hidden Posts & Boards'
  end

  def unhide
    if params[:unhide_boards].present?
      board_ids = params[:unhide_boards].map(&:to_i).compact.uniq
      views_to_update = BoardView.where(user_id: current_user.id).where(board_id: board_ids)
      views_to_update.each do |view| view.update(ignored: false) end
    end

    if params[:unhide_posts].present?
      post_ids = params[:unhide_posts].map(&:to_i).compact.uniq
      views_to_update = Post::View.where(user_id: current_user.id).where(post_id: post_ids)
      views_to_update.each do |view| view.update(ignored: false) end
    end

    redirect_to hidden_posts_path
  end

  def new
    @post = Post.new(user: current_user)
    @post.board_id = params[:board_id]
    @post.section_id = params[:section_id]
    @post.written.character = current_user.active_character
    @post.written.icon_id = (current_user.active_character ? current_user.active_character.default_icon.try(:id) : current_user.avatar_id)
    @page_title = 'New Post'

    @permitted_authors -= [current_user]
    if @post.board&.authors_locked?
      @author_ids = @post.board.writer_ids - [current_user.id]
      @authors_from_board = true
    end
  end

  def create
    import_thread and return if params[:button_import].present?

    @post = current_user.posts.new(permitted_params)
    @post.assign_attributes(written_params)
    @post.written.assign_attributes(written_params)

    preview and return if params[:button_preview].present?
    @post.settings = process_tags(Setting, obj_param: :post, id_param: :setting_ids)
    @post.content_warnings = process_tags(ContentWarning, obj_param: :post, id_param: :content_warning_ids)
    @post.labels = process_tags(Label, obj_param: :post, id_param: :label_ids)

    begin
      @post.save!
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        array: @post.errors.full_messages + @post.written.errors.full_messages,
        message: "Your post could not be saved because of the following problems:"
      }
      @reply = @post.written
      editor_setup
      @page_title = 'New Post'
      render :new
    else
      flash[:success] = "You have successfully posted."
      redirect_to post_path(@post)
    end
  end

  def show
    render :flat, layout: false and return if params[:view] == 'flat'
    show_post
  end

  def history
  end

  def delete_history
    audit_ids = @post.associated_audits.where(action: 'destroy').where(auditable_type: 'Reply') # all destroyed replies
    audit_ids = audit_ids.joins('LEFT JOIN replies ON replies.id = audits.auditable_id').where('replies.id IS NULL') # not restored
    audit_ids = audit_ids.group(:auditable_id).pluck(Arel.sql('MAX(audits.id)')) # only most recent per reply
    @audits = Audited::Audit.where(id: audit_ids).paginate(per_page: 1, page: page)

    if @audits.present?
      @audit = @audits.first
      @deleted = Reply.new(@audit.audited_changes)
      @preceding = @post.replies.where('id < ?', @audit.auditable_id).order(id: :desc).limit(2).reverse
      @preceding = [@post] unless @preceding.present?
      @following = @post.replies.where('id > ?', @audit.auditable_id).order(id: :asc).limit(2)
    end
  end

  def stats
  end

  def edit
  end

  def update
    mark_unread and return if params[:unread].present?
    mark_hidden and return if params[:hidden].present?

    require_permission
    return if performed?

    change_status and return if params[:status].present?
    change_authors_locked and return if params[:authors_locked].present?

    @post.assign_attributes(permitted_params(params[:button_preview].blank?))
    @post.assign_attributes(written_params)
    @post.written.assign_attributes(written_params)
    preview and return if params[:button_preview].present?

    @post.board ||= Board.find_by(id: Board::ID_SANDBOX)
    settings = process_tags(Setting, obj_param: :post, id_param: :setting_ids)
    warnings = process_tags(ContentWarning, obj_param: :post, id_param: :content_warning_ids)
    labels = process_tags(Label, obj_param: :post, id_param: :label_ids)

    is_author = @post.author_ids.include?(current_user.id)

    unless current_user.id == @post.user_id || is_author
      if @post.written.audit_comment.blank?
        flash[:error] = "You must provide a reason for your moderator edit."
        editor_setup
        render :edit and return
      else
        # no audit will be saved if a comment is the only change, so this should be safe
        @post.audit_comment = @post.written.audit_comment
      end
    end

    begin
      Post.transaction do
        @post.settings = settings
        @post.content_warnings = warnings
        @post.labels = labels
        @post.save!
        @post.author_for(current_user).update!(private_note: @post.private_note) if is_author
        @post.written.save!
      end
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        array: @post.errors.full_messages + @post.written.errors.full_messages,
        message: "Your post could not be saved because of the following problems:"
      }
      @audits = { post: @post.audits.count }
      editor_setup
      render :edit
    else
      flash[:success] = "Your post has been updated."
      redirect_to post_path(@post)
    end
  end

  def destroy
    unless @post.deletable_by?(current_user)
      flash[:error] = "You do not have permission to modify this post."
      redirect_to post_path(@post) and return
    end

    begin
      @post.destroy!
    rescue ActiveRecord::RecordNotDestroyed
      flash[:error] = {
        message: "Post could not be deleted.",
        array: @post.errors.full_messages
      }
      redirect_to post_path(@post)
    else
      flash[:success] = "Post deleted."
      redirect_to continuities_path
    end
  end

  def search
    @page_title = 'Search Posts'
    use_javascript('posts/search')

    # don't start blank if the parameters are set
    @setting = Setting.where(id: params[:setting_id]) if params[:setting_id].present?
    @character = Character.where(id: params[:character_id]) if params[:character_id].present?
    @user = User.active.where(id: params[:author_id]).ordered if params[:author_id].present?
    @board = Board.where(id: params[:board_id]) if params[:board_id].present?

    return unless params[:commit].present?

    @search_results = Post.ordered
    @search_results = @search_results.where(board_id: params[:board_id]) if params[:board_id].present?
    @search_results = @search_results.where(id: Setting.find(params[:setting_id]).post_tags.pluck(:post_id)) if params[:setting_id].present?
    if params[:subject].present?
      @search_results = @search_results.search(params[:subject]).where('LOWER(subject) LIKE ?', "%#{params[:subject].downcase}%")
    end
    @search_results = @search_results.complete if params[:completed].present?
    if params[:author_id].present?
      post_ids = nil
      params[:author_id].each do |author_id|
        author_posts = Post::Author.where(user_id: author_id, joined: true).pluck(:post_id)
        if post_ids.nil?
          post_ids = author_posts
        else
          post_ids &= author_posts
        end
        break if post_ids.empty?
      end
      @search_results = @search_results.where(id: post_ids.uniq)
    end
    if params[:character_id].present?
      post_ids = Reply.where(character_id: params[:character_id]).select(:post_id).distinct.pluck(:post_id)
      @search_results = @search_results.where(id: post_ids)
    end
    @search_results = posts_from_relation(@search_results, show_blocked: !!params[:show_blocked])
  end

  def warnings
    if logged_in?
      @post.hide_warnings_for(current_user)
      flash[:success] = "Content warnings have been hidden for this thread. Proceed at your own risk. "
      flash[:success] += "Please be aware that this will reset if new warnings are added later."
    else
      session[:ignore_warnings] = true
      flash[:success] = "All content warnings have been hidden. Proceed at your own risk."
    end
    params = {}
    params[:page] = page unless page.to_s == '1'
    params[:per_page] = per_page unless per_page.to_s == (current_user.try(:per_page) || 25).to_s
    redirect_to post_path(@post, params)
  end

  private

  def preview
    @post.board ||= Board.find_by_id(3)

    @author_ids = params.fetch(:post, {}).fetch(:unjoined_author_ids, [])
    @viewer_ids = params.fetch(:post, {}).fetch(:viewer_ids, [])
    @settings = process_tags(Setting, obj_param: :post, id_param: :setting_ids)
    @content_warnings = process_tags(ContentWarning, obj_param: :post, id_param: :content_warning_ids)
    @labels = process_tags(Label, obj_param: :post, id_param: :label_ids)
    @audits = { post: @post.audits.count } if @post.id.present?
    @reply = @post.written

    editor_setup
    @page_title = 'Previewing: ' + @post.subject.to_s
    render :preview
  end

  def mark_unread
    if params[:at_id].present?
      reply = Reply.find(params[:at_id])
      if reply && reply.post == @post
        @post.mark_read(current_user, at_time: reply.created_at - 1.second, force: true)
        flash[:success] = "Post has been marked as read until reply ##{reply.id}."
      end
      return redirect_to unread_posts_path
    end

    @post.views.where(user_id: current_user.id).first.try(:update, read_at: nil)
    flash[:success] = "Post has been marked as unread"
    redirect_to unread_posts_path
  end

  def mark_hidden
    if params[:hidden].to_s == 'true'
      @post.ignore(current_user)
      flash[:success] = "Post has been hidden"
    else
      @post.unignore(current_user)
      flash[:success] = "Post has been unhidden"
    end
    redirect_to post_path(@post)
  end

  def change_status
    unless Post.statuses.key?(params[:status])
      flash[:error] = "Invalid status selected."
      return redirect_to post_path(@post)
    end

    begin
      Post.transaction do
        @post.update!(status: params[:status])
        @post.mark_read(current_user, at_time: @post.tagged_at)
      end
    rescue ActiveRecord::RecordInvalid
      flash[:error] = {
        message: "Status could not be updated.",
        array: @post.errors.full_messages
      }
    else
      flash[:success] = "Post has been marked #{@post.status}."
    end
    redirect_to post_path(@post)
  end

  def change_authors_locked
    @post.authors_locked = (params[:authors_locked] == 'true')
    begin
      @post.save!
    rescue ActiveRecord::RecordInvalid
      flash[:error] = {
        message: "Post could not be updated.",
        array: @post.errors.full_messages
      }
    else
      flash[:success] = "Post has been #{@post.authors_locked? ? 'locked to' : 'unlocked from'} current authors."
    end
    redirect_to post_path(@post)
  end

  def editor_setup
    super
    @permitted_authors = User.active.ordered - (@post.try(:joined_authors) || [])
    @author_ids = permitted_params[:unjoined_author_ids].reject(&:blank?).map(&:to_i) if permitted_params.key?(:unjoined_author_ids)
    @author_ids ||= @post.try(:unjoined_author_ids) || []
  end

  def import_thread
    begin
      importer = PostImporter.new(params[:dreamwidth_url])
      importer.import(params[:board_id], current_user.id, section_id: params[:section_id], status: params[:status], threaded: params[:threaded])
    rescue PostImportError => e
      flash.now[:error] = e.api_error
      params[:view] = 'import'
      editor_setup
      render :new
    else
      flash[:success] = "Post has begun importing. You will be updated on progress via site message."
      redirect_to posts_path
    end
  end

  def find_model
    @post = Post.find_by_id(params[:id])

    unless @post
      flash[:error] = "Post could not be found."
      redirect_to continuities_path and return
    end

    unless @post.visible_to?(current_user)
      flash[:error] = "You do not have permission to view this post."
      redirect_to continuities_path and return
    end

    @page_title = @post.subject
  end

  def require_permission
    unless @post.editable_by?(current_user) || @post.metadata_editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this post."
      redirect_to post_path(@post)
    end
  end

  def require_import_permission
    return unless params[:view] == 'import' || params[:button_import].present?
    unless current_user.has_permission?(:import_posts)
      flash[:error] = "You do not have access to this feature."
      redirect_to new_post_path
    end
  end

  def permitted_params(include_associations=true)
    allowed_params = [
      :board_id,
      :section_id,
      :privacy,
      :subject,
      :description,
      :authors_locked,
      :audit_comment,
      :private_note
    ]

    # prevents us from setting (and saving) associations on preview()
    if include_associations
      allowed_params << {
        unjoined_author_ids: [],
        viewer_ids: []
      }
    end

    params.fetch(:post, {}).permit(allowed_params)
  end

  def written_params
    params.fetch(:reply, {}).permit(
      :content,
      :character_id,
      :icon_id,
      :character_alias_id,
      :audit_comment,
    )
  end
end
