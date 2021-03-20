module SpecTestHelper
  def login_as(user)
    request.session[:user_id] = user.id
  end

  def login
    login_as(create(:user))
  end
end

def stub_fixture(url, filename)
  url = url.gsub(/\#cmt\d+$/, '')
  file = Rails.root.join('spec', 'support', 'fixtures', "#{filename}.html")
  stub_request(:get, url).to_return(status: 200, body: File.new(file))
end
