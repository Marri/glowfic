class Reply < ApplicationRecord
  include Presentable
  include Writable
  include PgSearch::Model

  # define this scope here or Orderable will redefine it
  scope :ordered, -> { order(reply_order: :asc) }
  scope :ordered_manually, -> { ordered }
  include Orderable

  belongs_to :post, inverse_of: :replies, optional: false
  validate :author_can_write_in_post, on: :create
  audited associated_with: :post, except: :reply_order, update_with_comment_only: false

  after_create :notify_other_authors, :destroy_draft, :update_active_char, :set_last_reply, :update_post
  after_create_commit :update_post_authors # this can generate notification jobs
  after_update :update_post
  after_destroy :set_previous_reply_to_last, :remove_post_author
  after_commit :update_flat_post

  attr_accessor :skip_notify, :skip_post_update, :is_import, :skip_regenerate

  pg_search_scope(
    :search,
    against: %i(content),
    using: { tsearch: { dictionary: "english", highlight: {MaxFragments: 10} } },
  )

  scope :visible_to, ->(user) { where(post_id: Post.visible_to(user).select(:id)) }

  def post_page(per=25)
    per_page = per > 0 ? per : post.replies.count
    index = post.replies.where('reply_order < ?', self.reply_order).count
    (index / per_page) + 1
  end

  def last_updated
    updated_at
  end

  def order
    reply_order
  end

  def order=(val)
    self.reply_order = val
  end

  private

  def set_last_reply
    return if skip_post_update
    post.last_user = user
    post.last_reply = self
  end

  def update_post
    return if post.last_reply_id != id || skip_post_update
    return if (saved_changes.keys - Post::NON_TAGGED_ATTRS - ['updated_at']).empty?
    post.tagged_at = updated_at
    post.status = :active if post.on_hiatus?
    post.save
  end

  def update_active_char
    return if is_import
    user.update(:active_character => character)
  end

  def destroy_subsequent_replies
    Reply.where('id > ?', id).where(post_id: post_id).delete_all
    self.set_previous_reply_to_last
  end

  def set_previous_reply_to_last
    return if post.last_reply_id != id || skip_post_update
    # return unless needs to update last reply (this is destroyed, this is the last reply)
    post.last_reply = previous_reply
    post.last_user = (previous_reply || post).user
    post.tagged_at = (previous_reply || post).last_updated
    post.save
  end

  def destroy_draft
    return if is_import
    ReplyDraft.draft_for(post_id, user_id).try(:destroy)
  end

  def notify_other_authors
    return if skip_notify
    return if (previous_reply || post).user_id == user_id
    post.tagging_authors.each do |author|
      next if author.id == user_id
      next unless author.email.present?
      next unless author.email_notifications?
      UserMailer.post_has_new_reply(author.id, self.id).deliver
    end
  end

  def previous_reply
    @prev ||= post.replies.find_by(reply_order: reply_order - 1)
  end

  def author_can_write_in_post
    return unless post&.id && user
    errors.add(:user, "#{user.username} is not a valid continuity author for #{post.board.name}") unless user.writes_in?(post.board)
    return unless post.authors_locked?
    errors.add(:user, "#{user.username} cannot write in this post") unless post.author_for(user)&.can_reply
  end

  def update_flat_post
    return if skip_regenerate
    GenerateFlatPostJob.enqueue(post_id)
  end

  def update_post_authors
    post_author = post.author_for(user)
    return if post_author&.joined?

    if post_author
      post_author.update!(joined: true, joined_at: created_at)
    else
      post.post_authors.create!(user_id: user_id, joined: true, joined_at: created_at)
    end

    return if is_import
    post.user_joined(user)
  end

  def remove_post_author
    return if post.user_id == user_id
    return if post.replies.where(user: user).exists?

    # assume that if the post is author locked,
    # the user joined too early / is backtracking / etc
    # and should be unmarked as joined rather than
    # joined the wrong post outright and should be removed
    post_author = post.author_for(user)
    if post.authors_locked?
      post_author.update(joined: false)
    else
      post_author.destroy
    end
  end

  def ordered_attributes
    [:post_id]
  end
end
