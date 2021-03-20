require "#{File.dirname(__FILE__)}/../spec_helper"
RSpec.describe ClientApplication do
  fixtures :client_applications, :oauth_tokens
  before(:each) do
    @user = User.find_by_id(1) || create(:user)
    @user.save!
    @application = ClientApplication.create! :name => "Agree2", :url => "http://agree2.com", :user => @user, :callback_url => "http://test.com/callback"
  end

  it "should be valid" do
    expect(@application).to be_valid
  end

  it "should not have errors" do
    expect(@application.errors.full_messages).to eq []
  end

  it "should have key and secret" do
    expect(@application.key).not_to be_nil
    expect(@application.secret).not_to be_nil
  end

  it "should have credentials" do
    expect(@application.credentials).not_to be_nil
    expect(@application.credentials.key).to eq @application.key
    expect(@application.credentials.secret).to eq @application.secret
  end
end
