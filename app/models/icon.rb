class Icon < ApplicationRecord
  include Presentable

  S3_DOMAIN = '.s3.amazonaws.com'

  belongs_to :user, optional: false
  has_one :avatar_user, inverse_of: :avatar, class_name: 'User', foreign_key: :avatar_id, dependent: :nullify
  has_many :posts, dependent: false
  has_many :replies, dependent: false
  has_many :reply_drafts, dependent: :nullify
  has_many :galleries_icons, dependent: :destroy, inverse_of: :icon
  has_many :galleries, through: :galleries_icons, dependent: :destroy

  validates :keyword, presence: true
  validates :url,
    presence: true,
    length: { maximum: 255 }
  validate :url_is_url
  validate :uploaded_url_yours
  nilify_blanks

  before_validation :use_icon_host
  before_save :use_https
  before_update :delete_from_s3
  after_destroy :clear_icon_ids, :delete_from_s3

  scope :ordered, -> { order(Arel.sql('lower(keyword) asc'), created_at: :asc, id: :asc) }

  def uploaded?
    s3_key.present?
  end

  private

  def url_is_url
    return true if url.to_s.starts_with?('http://') || url.to_s.starts_with?('https://')
    self.url = url_was unless new_record?
    errors.add(:url, "must be an actual fully qualified url (http://www.example.com)")
  end

  def use_icon_host
    return unless uploaded?
    return unless url.present? && ENV['ICON_HOST'].present?
    return if url.to_s.include?(ENV['ICON_HOST'])
    self.url = ENV['ICON_HOST'] + url[(url.index(S3_DOMAIN).to_i + S3_DOMAIN.length)..-1]
  end

  def use_https
    return if uploaded?
    return unless url.starts_with?('http://')
    return unless url.include?("imgur.com") || url.include?("dreamwidth.org")
    self.url = url.sub('http:', 'https:')
  end

  def delete_from_s3
    return unless destroyed? || s3_key_changed?
    return unless s3_key_was.present?
    DeleteIconFromS3Job.perform_later(s3_key_was)
  end

  def uploaded_url_yours
    return unless uploaded?
    return if url.include?("users%2F#{user_id}%2Ficons%2F") && \
              s3_key.starts_with?("users/#{user_id}/icons/")

    self.url = url_was
    self.s3_key = s3_key_was
    errors.add(:url, 'is invalid')
  end

  def clear_icon_ids
    UpdateModelJob.perform_later(Post.to_s, {icon_id: id}, {icon_id: nil}, audited_user_id)
    UpdateModelJob.perform_later(Reply.to_s, {icon_id: id}, {icon_id: nil}, audited_user_id)
  end

  class UploadError < RuntimeError
  end
end
