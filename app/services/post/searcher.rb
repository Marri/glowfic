class Post::Searcher < Generic::Searcher
  def initialize(search=Post.ordered)
    super
  end

  def search(params)
    @search_results = @search_results.where(board_id: params[:board_id]) if params[:board_id].present?
    search_settings(params[:setting_id]) if params[:setting_id].present?
    search_subjects(params[:subject]) if params[:subject].present?
    @search_results = @search_results.complete if params[:completed].present?
    search_authors(params[:author_id]) if params[:author_id].present?
    search_characters(params[:character_id]) if params[:character_id].present?
    @search_results
  end

  def search_settings(setting_id)
    post_ids = Setting.find(setting_id).post_tags.pluck(:post_id)
    @search_results = @search_results.where(id: post_ids)
  end

  def search_subjects(subject)
    @search_results = @search_results.search(subject).where('LOWER(subject) LIKE ?', "%#{subject.downcase}%")
  end

  def search_authors(author_ids)
    author_posts = PostAuthor.where(user_id: author_ids, joined: true).select(:post_id).distinct.pluck(:post_id)
    @search_results = @search_results.where(id: author_posts)
  end

  def search_characters(character_id)
    post_ids = Reply.where(character_id: character_id).select(:post_id).distinct.pluck(:post_id)
    @search_results = @search_results.where(character_id: character_id).or(@search_results.where(id: post_ids))
  end
end
