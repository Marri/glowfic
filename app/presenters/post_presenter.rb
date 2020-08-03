class PostPresenter
  attr_reader :post

  def initialize(post)
    @post = post
  end

  def as_json(options={})
    return {} unless post
    return min_json(post) if options[:min]
    includeless_json(post)
  end

  private

  def min_json(post)
    post.as_json_without_presenter(only: [:id, :subject])
  end

  def includeless_json(post)
    attrs = %w(id subject description created_at tagged_at status section_order)
    post_json = post.as_json_without_presenter(only: attrs)
    post_json.merge({
      board: post.board,
      section: post.section,
      authors: post.joined_authors,
      num_replies: post.reply_count
    })
  end
end
