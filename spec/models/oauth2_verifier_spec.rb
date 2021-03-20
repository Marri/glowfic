require "#{File.dirname(__FILE__)}/../spec_helper"

RSpec.describe Oauth2Verifier do
  before(:each) do
    @user = create(:user)
    @client_application = ClientApplication.create! :user => @user, :name => "Client Application name", :url => "http://localhost/",
:callback_url => "http://localhost:3000/callback"
    @verifier = Oauth2Verifier.create! :client_application => @client_application, :user=>@user, :scope => "bbbb aaaa"
  end

  it "should be valid" do
    expect(@verifier).to be_valid
  end

  it "should have a code" do
    expect(@verifier.code).not_to be_nil
  end

  it "should not have a secret" do
    expect(@verifier.secret).to be_nil
  end

  it "should be authorized" do
    expect(@verifier).to be_authorized
  end

  it "should not be invalidated" do
    expect(@verifier).not_to be_invalidated
  end

  it "should generate query string" do
    expect(@verifier.to_query).to eq "code=#{@verifier.code}"
    @verifier.state="bbbb aaaa"
    expect(@verifier.to_query).to eq "code=#{@verifier.code}&state=bbbb+aaaa"
  end

  it "should properly exchange for token" do
    @token = @verifier.exchange!
    expect(@verifier).to be_invalidated
    expect(@token.user).to eq @verifier.user
    expect(@token.client_application).to eq @verifier.client_application
    expect(@token).to be_authorized
    expect(@token).not_to be_invalidated
    expect(@token.scope).to eq @verifier.scope
  end
end
