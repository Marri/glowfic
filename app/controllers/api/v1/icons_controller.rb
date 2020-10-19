class Api::V1::IconsController < Api::ApiController
  before_action :login_required, only: :s3_delete

  resource_description do
    description 'Processes S3 uploads that were not used'
  end

  api :POST, '/icons/s3_delete', 'Given an S3 key that the user has not turned into an icon, deletes the file from S3'
  param :s3_key, String, required: true, desc: 'S3 object key'
  error 401, "You must be logged in"
  error 403, "Icon does not belong to the user"
  error 422, "Invalid parameters provided: s3 key is in use."
  def s3_delete
    unless params[:s3_key].starts_with?("users/#{current_user.id}/")
      error = {message: "You do not have permission to modify this icon."}
      render json: {errors: [error]}, status: :forbidden and return
    end

    if Icon.where(s3_key: params[:s3_key]).exists?
      error = {message: "Only unused icons can be deleted."}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    S3_BUCKET.delete_objects(delete: {objects: [{key: params[:s3_key]}], quiet: true})
    render json: {}
  end
end
