class Post < ApplicationRecord
  include Concealable
  include Orderable
  include Owable
  include PgSearch::Model
  include Post::Status
  include Presentable
  include Viewable
  include Writable

  belongs_to :board, inverse_of: :posts, optional: false
  belongs_to :section, class_name: 'BoardSection', inverse_of: :posts, optional: true
  belongs_to :last_user, class_name: 'User', inverse_of: false, optional: false
  belongs_to :last_reply, class_name: 'Reply', inverse_of: false, optional: true
  has_one :flat_post, dependent: :destroy
  has_many :replies, inverse_of: :post, dependent: :delete_all
  has_many :reply_drafts, dependent: :destroy

  has_many :post_viewers, inverse_of: :post, dependent: :destroy
  has_many :viewers, through: :post_viewers, source: :user, dependent: :destroy
  has_many :favorites, as: :favorite, inverse_of: :favorite, dependent: :destroy
  has_many :views, class_name: 'Post::View', dependent: :destroy

  has_many :post_tags, inverse_of: :post, dependent: :destroy
  has_many :labels, -> { ordered_by_post_tag }, through: :post_tags, source: :label, dependent: :destroy
  has_many :settings, -> { ordered_by_post_tag }, through: :post_tags, source: :setting, dependent: :destroy
  has_many :content_warnings, -> { ordered_by_post_tag }, through: :post_tags, source: :content_warning,
    after_add: :reset_warnings, dependent: :destroy

  has_many :index_posts, inverse_of: :post, dependent: :destroy
  has_many :indexes, inverse_of: :posts, through: :index_posts, dependent: :destroy
  has_many :index_sections, inverse_of: :posts, through: :index_posts, dependent: :destroy

  has_many :linked_post_joins, class_name: 'PostLink', foreign_key: :linking_post_id, inverse_of: :linking_post, dependent: :destroy
  has_many :linking_post_joins, class_name: 'PostLink', foreign_key: :linked_post_id, inverse_of: :linked_post, dependent: :destroy
  has_many :linked_posts, class_name: 'Post', through: :linked_post_joins, inverse_of: :linking_posts
  has_many :linking_posts, class_name: 'Post', through: :linking_post_joins, inverse_of: :linked_posts

  accepts_nested_attributes_for :linked_post_joins, allow_destroy: true, reject_if: :all_blank

  attr_accessor :is_import
  attr_writer :skip_edited

  validates :subject, presence: true
  validates :description, length: { maximum: 255 }
  validate :valid_board, :valid_board_section

  before_create :build_initial_flat_post, :set_timestamps
  before_update :set_timestamps
  before_validation :set_last_user, on: :create
  after_commit :notify_followers, on: :create
  after_commit :invalidate_caches, on: :update

  NON_EDITED_ATTRS = %w(id created_at updated_at edited_at tagged_at last_user_id last_reply_id section_order)
  NON_TAGGED_ATTRS = %w(icon_id character_alias_id character_id)
  audited except: NON_EDITED_ATTRS, update_with_comment_only: false
  has_associated_audits

  pg_search_scope(
    :search,
    against: %i(
      subject
      content
    ),
    using: { tsearch: { dictionary: "english" } },
  )

  scope :ordered, -> { order(tagged_at: :desc).order(Arel.sql('lower(subject) asc'), id: :asc) }

  scope :ordered_in_section, -> { order(section_order: :asc) }

  scope :ordered_by_id, -> { order(id: :asc) }

  scope :ordered_by_index, -> { order('index_posts.section_order asc') }

  scope :no_tests, -> { where.not(board_id: Board::ID_SITETESTING) }

  # rubocop:disable Style/TrailingCommaInArguments
  scope :with_has_content_warnings, -> {
    select(
      <<~SQL
        (
          SELECT tags.id IS NOT NULL FROM tags LEFT JOIN post_tags ON tags.id = post_tags.tag_id
          WHERE tags.type = 'ContentWarning' AND post_tags.post_id = posts.id LIMIT 1
        ) AS has_content_warnings
      SQL
    )
  }
  # rubocop:enable Style/TrailingCommaInArguments

  scope :with_reply_count, -> {
    select('(SELECT COUNT(*) FROM replies WHERE replies.post_id = posts.id) AS reply_count')
  }

  scope :visible_to, ->(user) {
    if user
      where(user_id: user.id)
        .or(where(privacy: [:public, :registered]))
        .or(where(privacy: :access_list, id: user.visible_posts))
        .where.not(id: user.blocked_posts)
    else
      where(privacy: :public)
    end
  }

  def visible_to?(user)
    return false if user&.author_blocking?(self, author_ids)
    return true if privacy_public?
    return false unless user
    return true if privacy_registered? || user.admin?
    return user.id == user_id if privacy_private?
    (post_viewers.pluck(:user_id) + [user_id]).include?(user.id)
  end

  def build_new_reply_for(user, reply_params={})
    draft = ReplyDraft.draft_reply_for(self, user)
    return draft if draft.present?

    reply = Reply.new(reply_params.merge(post: self, user: user))
    return reply if reply_params.present?

    user_replies = replies.where(user_id: user.id).ordered
    if user_replies.exists?
      last_user_reply = user_replies.last
      reply.character_id = last_user_reply.character_id
      reply.character_alias_id = last_user_reply.character_alias_id
    elsif self.user == user
      reply.character_id = self.character_id
      reply.character_alias_id = self.character_alias_id
    elsif user.active_character_id.present?
      reply.character_id = user.active_character_id
    end

    if reply.character_id.nil?
      reply.icon_id = user.avatar_id
    else
      reply.icon_id = reply.character.default_icon.try(:id)
    end

    reply
  end

  def first_unread_for(user)
    return @first_unread if @first_unread
    viewed_at = last_read(user) || board.last_read(user)
    return @first_unread = self unless viewed_at
    return unless replies.exists?
    reply = replies.where('created_at > ?', viewed_at).ordered.first
    @first_unread ||= reply
  end

  def last_seen_reply_for(user)
    return @last_seen if @last_seen
    return unless replies.exists? # unlike first_unread_for we don't care about the post
    viewed_at = last_read(user) || board.last_read(user)
    return unless viewed_at
    reply = replies.where('created_at <= ?', viewed_at).ordered.last
    @last_seen = reply
  end

  def recent_characters_for(user, count)
    # fetch the (count) most recent non-nil character_ids for user in post
    recent_ids = replies.where(user_id: user.id)
      .where.not(character_id: nil)
      .limit(count)
      .group('character_id')
      .select('DISTINCT character_id, MAX(id)')
      .order(Arel.sql('MAX(id) desc'))
      .pluck(:character_id)

    # add the post's character_id to the last one if it's not over the limit
    recent_ids << character_id if character_id.present? && user_id == user.id && recent_ids.length < count && !recent_ids.include?(character_id)

    # fetch the relevant characters and sort by their index in the recent list
    Character.where(id: recent_ids).includes(:default_icon).sort_by do |x|
      recent_ids.index(x.id)
    end
  end

  def hide_warnings_for(user)
    view_for(user).update(warnings_hidden: true)
  end

  def show_warnings_for?(user)
    return false if user.hide_warnings
    !view_for(user).try(:warnings_hidden)
  end

  def last_updated
    edited_at
  end

  def read_time_for(viewing_replies)
    return self.edited_at if viewing_replies.empty?

    most_recent = viewing_replies.max_by(&:reply_order)
    most_recent_id = replies.select(:id).ordered.last.id
    return most_recent.created_at unless most_recent.id == most_recent_id # not on last page
    return most_recent.updated_at if most_recent.updated_at > edited_at

    # testing for case where the post was changed in status more recently than the last reply
    audits_exist = audits.where('created_at > ?', most_recent.created_at).where(action: 'update')
    audits_exist = audits_exist.where("(audited_changes -> 'status' ->> 1)::integer = ?", Post.statuses[:complete])
    return most_recent.updated_at unless audits_exist.exists?
    self.edited_at
  end

  def metadata_editable_by?(user)
    return false unless user
    return true if user == self.user
    return true if user.has_permission?(:edit_posts)
    author_ids.include?(user.id)
  end

  def taggable_by?(user)
    return false unless user
    return false if complete? || abandoned?
    return false unless user.writes_in?(board)
    return true unless authors_locked?
    author_ids.include?(user.id)
  end

  def total_word_count
    return word_count unless replies.exists?
    contents = replies.pluck(:content)
    contents[0] = contents[0].split.size
    word_count + contents.inject{|r, e| r + e.split.size}.to_i
  end

  def word_count_for(user)
    sum = 0
    sum = word_count if user_id == user.id
    return sum unless replies.where(user_id: user.id).exists?

    contents = replies.where(user_id: user.id).pluck(:content)
    contents[0] = contents[0].split.size
    sum + contents.inject{|r, e| r + e.split.size}.to_i
  end

  # only returns for authors who have written in the post (it's zero for authors who have not joined)
  def author_word_counts
    joined_authors.map { |author| [!author.deleted? ? author.username : '(deleted user)', word_count_for(author)] }.sort_by{|a| -a[1] }
  end

  def character_appearance_counts
    reply_counts = replies.joins(:character).group(:character_id).count
    reply_counts[character_id] = reply_counts[character_id].to_i + 1
    Character.where(id: reply_counts.keys).map { |c| [c, reply_counts[c.id]]}.sort_by{|a| -a[1] }
  end

  def has_content_warnings?
    return read_attribute(:has_content_warnings) if has_attribute?(:has_content_warnings)
    content_warnings.exists?
  end

  def reply_count
    return read_attribute(:reply_count) if has_attribute?(:reply_count)
    replies.count
  end

  def last_user_deleted?
    return read_attribute(:last_user_deleted) if has_attribute?(:last_user_deleted)
    last_user.deleted?
  end

  def user_joined(user)
    NotifyFollowersOfNewPostJob.perform_later(self.id, user.id)
  end

  def prev_post(user)
    adjacent_posts_for(user) { |relation| relation.reverse_order.find_by('section_order < ?', self.section_order) }
  end

  def next_post(user)
    adjacent_posts_for(user) { |relation| relation.find_by('section_order > ?', self.section_order) }
  end

  private

  def adjacent_posts_for(user)
    return unless board.ordered?
    return unless section || board.board_sections.empty?
    yield Post.where(board_id: self.board_id, section_id: self.section_id).visible_to(user).ordered_in_section
  end

  def valid_board
    return unless board_id.present?
    return unless new_record? || board_id_changed?
    return if board.open_to?(user)
    errors.add(:board, "is invalid – you must be able to write in it")
  end

  def valid_board_section
    return unless section.present?
    return if section.board_id == board_id
    errors.add(:section, "must be in the post's board")
  end

  def set_last_user
    self.last_user = user
  end

  # timestamps start existing between before_save and before_create/update
  def set_timestamps
    return if skip_edited
    self.edited_at = self.updated_at
    return if skip_tagged
    return if replies.exists? && (!status_changed? || !complete?)
    self.tagged_at = self.updated_at
  end

  def skip_edited
    @skip_edited || (changed_attributes.keys - NON_EDITED_ATTRS).empty?
  end

  def skip_tagged
    (changed_attributes.keys - NON_TAGGED_ATTRS - NON_EDITED_ATTRS).empty?
  end

  def ordered_attributes
    [:section_id, :board_id]
  end

  def build_initial_flat_post
    build_flat_post
    true
  end

  def reset_warnings(_warning)
    Post::View.where(post_id: id).update_all(warnings_hidden: false)
  end

  def notify_followers
    return if is_import
    NotifyFollowersOfNewPostJob.perform_later(self.id, user_id)
  end

  def invalidate_caches
    return unless saved_change_to_authors_locked?
    Post::Author.clear_cache_for(authors)
  end
end
