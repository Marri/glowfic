class Reply::Searcher < Generic::Searcher
  def initialize(search=Reply.unscoped, templates:, users:)
    super
  end

  def search(params, post: nil, page: 1)
    @search_results = @search_results.where(user_id: params[:author_id]) if params[:author_id].present?
    @search_results = @search_results.where(character_id: params[:character_id]) if params[:character_id].present?
    @search_results = @search_results.where(icon_id: params[:icon_id]) if params[:icon_id].present?
    search_content(params[:subj_content]) if params[:subj_content].present?
    sort(params[:sort], params[:subject_content]) if params[:sort].present?
    search_posts(post, params[:board_id]) if post || params[:board_id].present?
    search_templates(params[:template_id]) if params[:template_id].present?
    select_templates(params[:author_id]) if params[:author_id].present? && params[:template_id].blank?
    format_results(page, params[:condensed])
  end

  def search_content(content)
    @search_results = @search_results.search(content).with_pg_search_highlight
    exact_phrases = content.scan(/"([^"]*)"/)
    if exact_phrases.present?
      exact_phrases.each do |phrase|
        phrase = phrase.first.strip
        next if phrase.blank?
        @search_results = @search_results.where("replies.content LIKE ?", "%#{phrase}%")
      end
    end
  end

  def sort(sort, content)
    append_rank = content.present? ? ', rank DESC' : ''
    if sort == 'created_new'
      @search_results = @search_results.except(:order).order('replies.created_at DESC' + append_rank)
    elsif sort == 'created_old'
      @search_results = @search_results.except(:order).order('replies.created_at ASC' + append_rank)
    elsif content.blank?
      @search_results = @search_results.order('replies.created_at DESC')
    end
  end

  def search_posts(post, board_id)
    if post
      @search_results = @search_results.where(post_id: post.id)
    elsif board_id.present?
      post_ids = Post.where(board_id: board_id).pluck(:id)
      @search_results = @search_results.where(post_id: post_ids)
    end
  end

  def format_results(page, condensed)
    @search_results = @search_results
      .select('replies.*, characters.name, characters.screenname, users.username, users.deleted as user_deleted')
      .joins(:user)
      .left_outer_joins(:character)
      .with_edit_audit_counts
      .paginate(page: page)
      .includes(:post)

    unless condensed
      @search_results = @search_results
        .select('icons.keyword, icons.url')
        .left_outer_joins(:icon)
    end
  end
end
