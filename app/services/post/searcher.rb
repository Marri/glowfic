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
    post_ids = nil
    author_ids.each do |author_id|
      author_posts = PostAuthor.where(user_id: author_id, joined: true).pluck(:post_id)
      if post_ids.nil?
        post_ids = author_posts
      else
        post_ids &= author_posts
      end
      break if post_ids.empty?
    end
    @search_results = @search_results.where(id: post_ids.uniq)
  end

  def search_characters(character_id)
    post_ids = Reply.where(character_id: character_id).select(:post_id).distinct.pluck(:post_id)
    @search_results = @search_results.where(character_id: character_id).or(@search_results.where(id: post_ids))
  end
end
