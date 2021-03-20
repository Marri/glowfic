module OAuthControllerSpecHelper
  include ActiveJob::TestHelper
  def login_as_application_owner
    @user = create(:user)
    login_as(@user)
  end

  def setup_oauth
    @server=OAuth::Server.new "http://localhost:3000"
    @client_application = ClientApplication.create! :user => @user, :name => "Client Application name", :url => "http://localhost/",
:callback_url => "http://localhost:3000/callback"
    @consumer=OAuth::Consumer.new(@client_application.key, @client_application.secret, {:site=>"http://localhost:3000"})

    @user.client_applications=[@client_application]
    @current_client_application = @client_application
    @current_client_applications = @user.client_applications

    @access_token = AccessToken.create! :user => @user, :client_application => @client_application
  end

  def setup_oauth_for_user
    login_as_application_owner
    setup_oauth
    @user.reload
    @current_user = @user
  end

  def sign_request_with_oauth(token=nil)
    ActionController::TestRequest.use_oauth=true
    @request.configure_oauth(@consumer, token)
  end

  def setup_to_authorize_request
    setup_oauth
  end
end
