require "#{File.dirname(__FILE__)}/../spec_helper"

RSpec.describe Oauth2Token do
  fixtures :client_applications, :oauth_tokens
  before(:each) do
    @user = User.find_by_id(1) || create(:user)
    @token = Oauth2Token.create! :client_application => client_applications(:one), :user => @user
  end

  it "should be valid" do
    expect(@token).to be_valid
  end

  it "should have a token" do
    expect(@token.token).not_to be_nil
  end

  it "should have a secret" do
    expect(@token.secret).not_to be_nil
  end

  it "should be authorized" do
    expect(@token).to be_authorized
  end

  it "should not be invalidated" do
    expect(@token).not_to be_invalidated
  end

  it "should generate correct json and query strong" do
    expect(@token.as_json).to eq({:access_token => @token.token, :token_type => 'bearer'})
    expect(@token.to_query).to eq "access_token=#{@token.token}&token_type=bearer"
  end

  it "should generate correct json and query string and include state in query if present" do
    @token.state = 'bb bb'
    expect(@token.as_json).to eq({:access_token => @token.token, :token_type => 'bearer'})
    expect(@token.to_query).to eq "access_token=#{@token.token}&token_type=bearer&state=bb+bb"
  end

  it "should generate correct json and query string and include scope in query if present" do
    @token.scope = 'bbbb aaaa'
    expect(@token.as_json).to eq({:access_token => @token.token, :token_type => 'bearer'})
    expect(@token.to_query).to eq("access_token=#{@token.token}&token_type=bearer&scope=bbbb+aaaa")
  end

  it "should generate correct json and include expires_in if present" do
    @token.expires_at = 1.hour.from_now
    expect(@token.as_json).to eq({ :access_token => @token.token, :token_type => 'bearer', :expires_in => 3600 })
    expect(@token.to_query).to eq("access_token=#{@token.token}&token_type=bearer&expires_in=3600")
  end
end
