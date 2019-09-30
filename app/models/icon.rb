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

  has_one_attached :image, dependent: :purge_later

  validates :keyword, presence: true
  validates :url,
    presence: true,
    length: { maximum: 255 }
  validate :url_is_url
  validate :uploaded_url_not_in_use
  nilify_blanks

  before_validation :setup_uploaded_url, if: :new_record
  before_save :use_https, :setup_uploaded_url
  before_update :delete_from_s3, :delete_from_storage
  after_destroy :clear_icon_ids, :delete_from_s3

  scope :ordered, -> { order(Arel.sql('lower(keyword) asc'), created_at: :asc, id: :asc) }

  def uploaded?
    s3_key.present? || image.attached?
  end

  private

  def url_is_url
    return true if url.to_s.starts_with?('http://') || url.to_s.starts_with?('https://')
    self.url = url_was unless new_record?
    errors.add(:url, "must be an actual fully qualified url (http://www.example.com)")
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

  def delete_from_storage
    return unless self.url_changed? && self.image.attached? && self.image.changes.empty?
    return if self.url == Rails.application.routes.url_helpers.rails_blob_url(self.image)
    image.purge_later
  end

  def uploaded_url_not_in_use
    return unless s3_key.present?
    check = Icon.where(s3_key: s3_key)
    check = check.where.not(id: id) unless new_record?
    return unless check.exists?
    self.url = url_was
    self.s3_key = s3_key_was
    errors.add(:url, 'has already been taken')
  end

  def clear_icon_ids
    UpdateModelJob.perform_later(Post.to_s, {icon_id: id}, {icon_id: nil})
    UpdateModelJob.perform_later(Reply.to_s, {icon_id: id}, {icon_id: nil})
  end

  def setup_uploaded_url
    return unless self.image.attached?
    self.url = Rails.application.routes.url_helpers.rails_blob_url(self.image)
  end

  class UploadError < RuntimeError
  end
end
