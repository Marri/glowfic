# frozen_string_literal: true
class UploadingController < GenericController
  protected

  def set_s3_url
    return if params[:type] == "existing"

    if !Rails.env.production? && S3_BUCKET.nil?
      logger.error "S3_BUCKET does not exist; icon upload will FAIL."
      @s3_direct_post = Struct.new(:url, :fields).new('', nil)
      return
    end

    @s3_direct_post = S3_BUCKET.presigned_post(
      key: "users/#{current_user.id}/icons/${filename}",
      success_action_status: '201',
      acl: 'public-read',
      content_type_starts_with: 'image/',
      cache_control: 'public, max-age=31536000')
  end
end
