class Message < ApplicationRecord
  # TODO drop marked_*
  belongs_to :sender, class_name: 'User', inverse_of: :sent_messages, optional: true
  belongs_to :recipient, class_name: 'User', inverse_of: :messages, optional: false
  belongs_to :parent, class_name: 'Message', inverse_of: false, optional: true
  belongs_to :first_thread, class_name: 'Message', foreign_key: :thread_id, inverse_of: false, optional: false

  validates :sender, presence: { if: Proc.new { |m| m.sender_id != 0 } }
  validate :unblocked_recipient, on: :create

  before_validation :set_thread_id, :remove_deleted_recipient
  before_create :check_recipient
  after_create :notify_recipient
  after_commit :invalidate_caches

  scope :ordered_by_id, -> { order(id: :asc) }
  scope :ordered_by_thread, -> { order(thread_id: :asc, id: :desc) }
  scope :unread, -> { where(unread: true) }

  CACHE_VERSION = 1

  def visible_to?(user)
    user_ids.include?(user.id)
  end

  def unempty_subject
    return first_thread.unempty_subject if thread_id != id
    return '(no title)' if subject.blank?
    subject
  end

  def last_in_thread
    return self if thread_id == id
    @last ||= self.class.where(thread_id: thread_id).ordered_by_id.first
  end

  def box(user)
    @box ||= (sender_id == user.id ? 'outbox' : 'inbox')
  end

  def user_ids
    [sender_id, recipient_id]
  end

  def num_in_thread
    self.class.where(thread_id: thread_id).count
  end

  def sender_name
    return 'Glowfic Constellation' if site_message?
    sender.username
  end

  def site_message?
    sender_id.to_i.zero?
  end

  def self.unread_count_for(user)
    Rails.cache.fetch(Message.cache_string_for(user.id), expires_in: 1.day) do
      user.messages.unread.count
    end
  end

  def self.cache_string_for(user_id)
    "#{Rails.env}.#{CACHE_VERSION}.unread_message_count.#{user_id}"
  end

  private

  def set_thread_id
    return if thread_id.present?
    self.first_thread = self
  end

  def check_recipient
    return unless sender && recipient
    return if sender.can_interact_with?(recipient)
    self.visible_inbox = false
    self.unread = false
  end

  def notify_recipient
    return if recipient_id == sender_id
    return unless visible_inbox
    return unless recipient.email.present?
    return unless recipient.email_notifications?
    UserMailer.new_message(self.id).deliver
  end

  def unblocked_recipient
    return unless sender && recipient
    return unless sender.has_interaction_blocked?(recipient)
    errors.add(:recipient, "must not be blocked by you")
  end

  def remove_deleted_recipient
    return unless recipient&.deleted?
    self.recipient = nil
  end

  def invalidate_caches
    Rails.cache.delete(Message.cache_string_for(recipient.id))
  end
end
