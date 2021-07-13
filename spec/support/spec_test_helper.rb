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
      parameter.transform_values!{ |v| transform_element(v) }
      parameter.sort_by{ |k, _v| k }.to_h
    end

    def transform_element(ele)
      if ele.is_a?(ActiveRecord::Relation)
        ele = ele.ordered if ele.respond_to?(:ordered)
        ele.to_a
      elsif ele.is_a?(Array)
        ele = ele.sort unless ele[0].is_a?(Hash)
        ele.map { |e| transform_element(e) }
      elsif ele.is_a?(Hash)
        transform(ele)
      elsif ele.is_a?(ActiveRecord::Base)
        ele
      else
        ele.to_s
      end
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
