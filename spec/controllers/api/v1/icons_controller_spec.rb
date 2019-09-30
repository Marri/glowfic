require "spec_helper"
require "support/s3_bucket_helper"

RSpec.describe Api::V1::IconsController do
  describe "POST s3_delete", show_in_doc: true do
    it "should require login" do
      handle_s3_bucket
      expect(S3_BUCKET).not_to receive(:delete_objects)
      post :s3_delete
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "should require s3_key param" do
      handle_s3_bucket
      expect(S3_BUCKET).not_to receive(:delete_objects)
      login
      post :s3_delete
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Missing parameter s3_key")
    end

    it "should require your own icon" do
      handle_s3_bucket
      user = create(:user)
      login_as(user)

      expect(S3_BUCKET).not_to receive(:delete_objects)
      post :s3_delete, params: { s3_key: "users/#{user.id}1/icons/hash_name.png" }

      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("That is not your icon.")
    end

    it "should not allow deleting a URL in use" do
      handle_s3_bucket
      icon = create(:old_uploaded_icon)
      login_as(icon.user)
      expect(S3_BUCKET).not_to receive(:delete_objects)
      post :s3_delete, params: { s3_key: icon.s3_key }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Only unused icons can be deleted.")
    end

    it "should delete the URL" do
      handle_s3_bucket
      user = create(:user)
      icon = build(:old_uploaded_icon, user: user)
      login_as(user)
      delete_key = {delete: {objects: [{key: icon.s3_key}], quiet: true}}
      expect(S3_BUCKET).to receive(:delete_objects).with(delete_key)
      post :s3_delete, params: { s3_key: icon.s3_key }
      expect(response).to have_http_status(200)
      expect(response.json).to eq({})
    end
  end
end
