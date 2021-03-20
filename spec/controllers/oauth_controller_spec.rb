RSpec.describe OauthController, type: :controller do
  include ActiveJob::TestHelper
  before(:each) do
    @user = create(:user)
    login_as(@user)
    @client_application = ClientApplication.create! :user => @user, :name => "Client Application name", :url => "http://localhost/",
:callback_url => "http://localhost:3000/callback"
  end

  describe "GET authorize" do
    it "succeeds" do
      get :authorize, params: {client_id: @client_application.key}
      expect(response.status).to eq(200)
    end

    it "renders template" do
      get :authorize, params: {client_id: @client_application.key}
      expect(response).to render_template('oauth2_authorize')
    end
  end

  describe "POST authorize" do
    it "redirect_to callback_url" do
      post :authorize, params: {:authorize => '1', :client_id => @client_application.key}
      expect(response).to redirect_to(/\Ahttp:\/\/localhost:3000\/callback/)
    end
  end

  describe "POST access_token" do
    it "should render nothing with no valid token" do
      post :access_token, params: {token: nil}
      expect(response.status).to eq(401)
    end
  end

  describe "POST token" do
    it "should render nothing with no valid token" do
      expect {post :token, params: {token: 999} }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should return access_token" do
      verifier = Oauth2Verifier.create! :client_application => @client_application, :user=>@user, :scope => "account"
      ProviderAuthorizer.new @user, true,
        {client_id: @client_application.key, scope: 'account', redirect_uri: @client_application.callback_url}
      post :token,
        params: {
          client_id: @client_application.key,
          client_secret: @client_application.secret,
          code: verifier.code,
          grant_type: "authorization_code",
          redirect_uri: @client_application.callback_url,
          state: nil,
          permitted: true
        }
      puts response.body
      expect(response.status).to eq(200)
    end
  end
end
