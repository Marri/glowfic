RSpec.describe Api::V1::IconsController do
  describe "POST s3_delete", show_in_doc: true do
    it "should require login" do
      expect(S3_BUCKET).not_to receive(:delete_objects)
      post :s3_delete
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "should require s3_key param" do
      expect(S3_BUCKET).not_to receive(:delete_objects)
      api_login
      post :s3_delete
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Missing parameter s3_key")
    end

    it "should require your own icon" do
      user = create(:user)
      api_login_as(user)

      expect(S3_BUCKET).not_to receive(:delete_objects)
      post :s3_delete, params: { s3_key: "users/#{user.id}1/icons/hash_name.png" }

      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("That is not your icon.")
    end

    it "should not allow deleting a URL in use" do
      icon = create(:uploaded_icon)
      api_login_as(icon.user)
      expect(S3_BUCKET).not_to receive(:delete_objects)
      post :s3_delete, params: { s3_key: icon.s3_key }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Only unused icons can be deleted.")
    end

    it "should delete the URL" do
      user = create(:user)
      icon = build(:uploaded_icon, user: user)
      api_login_as(user)
      delete_key = {delete: {objects: [{key: icon.s3_key}], quiet: true}}
      expect(S3_BUCKET).to receive(:delete_objects).with(delete_key)
      post :s3_delete, params: { s3_key: icon.s3_key }
      expect(response).to have_http_status(200)
      expect(response.json).to eq({})
    end
  end
end
