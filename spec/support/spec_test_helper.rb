module SpecTestHelper
  def login_as(user)
    request.session[:user_id] = user.id
  end

  def login
    login_as(create(:user))
  end

  RSpec::Matchers.define :match_hash do |expected|
    match do |actual|
      return false unless expected.is_a?(Hash) && actual.is_a?(Hash)
      @actual = transform(actual)
      @expected = transform(expected)
      @actual.eql?(@expected)
    end

    def transform(parameter)
      parameter.transform_keys!(&:to_s)
      parameter.transform_values! do |v|
        if v.is_a?(ActiveRecord::Relation)
          v.to_a
        elsif v.is_a?(Array)
          v
        else
          v.to_s
        end
      end
      parameter.sort_by{ |k, _v| k }.to_h
    end

    diffable
    attr_reader :actual, :expected
  end
end

def stub_fixture(url, filename)
  url = url.gsub(/\#cmt\d+$/, '')
  file = Rails.root.join('spec', 'support', 'fixtures', filename + '.html')
  stub_request(:get, url).to_return(status: 200, body: File.new(file))
end
