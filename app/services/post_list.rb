class PostList
  extend ActiveModel::Translation
  extend ActiveModel::Validations

  attr_reader :errors, :opened_ids, :unread_ids

  def initialize(relation, no_tests: true, select: '', user: nil, max: false)
    @errors = ActiveModel::Errors.new(self)
    @user = user
    @posts = expand_posts(relation, select: select, no_tests: no_tests, max: max)
  end

  def format_posts(with_pagination: true, page: nil)
    @posts = @posts.paginate(page: page, per_page: 25) if with_pagination

    if @user.present?
      @opened_ids ||= PostView.where(user_id: @user.id).where('read_at IS NOT NULL').pluck(:post_id)

      opened_posts = PostView.where(user_id: @user.id).where('read_at IS NOT NULL').where(post_id: @posts.map(&:id)).select([:post_id, :read_at])
      @unread_ids ||= []
      @unread_ids += opened_posts.select do |view|
        post = @posts.detect { |p| p.id == view.post_id }
        post && view.read_at < post.tagged_at
      end.map(&:post_id)
    end

    @posts
  end

  private

  def expand_posts(relation, no_tests:, select:, max:)
    if max
      posts = relation.select('posts.*, max(boards.name) as board_name, max(users.username) as last_user_name'+ select)
    else
      posts = relation.select('posts.*, boards.name as board_name, users.username as last_user_name'+ select)
    end

    posts = posts
      .visible_to(@user)
      .joins(:board)
      .joins(:last_user)
      .includes(:authors)
      .with_has_content_warnings
      .with_reply_count

    posts = posts.no_tests if no_tests
    posts
  end
end
