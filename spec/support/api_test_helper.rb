module ApiTestHelper
  def api_login
    api_login_as(create(:user))
  end

  def api_login_as(user)
    token = Authentication.generate_api_token(user)
    request.headers.merge({'Authorization': "Bearer #{token}"})
    user
  end
end
