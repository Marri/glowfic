RSpec.describe Api::V1::SessionsController do
  describe "POST create" do
    let(:password) { 'password' }
    let(:user) { create(:user, password: password) }

    it "requires logout" do
      api_login_as(user)
      post :create, params: { username: user.username, password: password }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged out to call this endpoint.")
    end

    it "requires an existing username" do
      nonusername = 'nonuser'
      expect(User.find_by(username: nonusername)).to be_nil
      post :create, params: { username: nonusername }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("That username does not exist.")
    end

    it "requires undeleted user" do
      user = create(:user, deleted: true)
      post :create, params: { username: user.username }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("That username does not exist.")
    end

    it "requires unsuspended user" do
      user = create(:user, role_id: Permissible::SUSPENDED)
      post :create, params: { username: user.username }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You could not be logged in.")
    end

    it "disallows logins with old passwords when reset is pending" do
      create(:password_reset, user: user)
      expect(user.password_resets.active.unused).not_to be_empty
      post :create, params: { username: user.username }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("The password for this account has been reset. Please check your email.")
    end

    it "requires a valid password" do
      post :create, params: { username: user.username, password: password + "-not" }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You have entered an incorrect password.")
    end

    it "logs in successfully with salt_uuid" do
      post :create, params: { username: user.username, password: password }

      expect(response).to have_http_status(200)
      expect(response.json).to have_key('token')
      decoded_token = JWT.decode(response.json['token'], Rails.application.secrets.secret_key_api)[0]
      expect(decoded_token['user_id']).to eq(user.id)
    end

    it "logs in successfully without salt_uuid and sets it" do
      user.update_columns(salt_uuid: nil, crypted: user.send(:old_crypted_password, password)) # rubocop:disable Rails/SkipsModelValidations
      user.reload
      expect(user.salt_uuid).to be_nil
      expect(session[:user_id]).to be_nil
      expect(controller.send(:logged_in?)).not_to eq(true)

      post :create, params: { username: user.username, password: password }

      expect(response).to have_http_status(200)
      expect(response.json).to have_key('token')
      decoded_token = JWT.decode(response.json['token'], Rails.application.secrets.secret_key_api)[0]
      expect(decoded_token['user_id']).to eq(user.id)
      expect(user.reload.salt_uuid).not_to be_nil
      expect(user.authenticate(password)).to eq(true)
    end
  end
end
