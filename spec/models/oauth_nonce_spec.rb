require "#{File.dirname(__FILE__)}/../spec_helper"
require 'oauth/helper'
RSpec.describe OauthNonce do
  include OAuth::Helper
  before(:each) do
    @oauth_nonce = OauthNonce.remember(generate_key, Time.now.to_i)
  end

  it "should be valid" do
    expect(@oauth_nonce).to be_valid
  end

  it "should not have errors" do
    expect(@oauth_nonce.errors.full_messages).to eq([])
  end

  it "should not be a new record" do
    expect(@oauth_nonce).not_to be_new_record
  end

  it "should not allow a second one with the same values" do
    expect(OauthNonce.remember(@oauth_nonce.nonce, @oauth_nonce.timestamp)).to eq(false)
  end
end
