class ProviderAuthorizer
  attr_accessor :user, :params

  def initialize(user, authorized, params={})
    @user = user
    @params = params
    @authorized = authorized
  end

  def app
    @app ||= ::ClientApplication.find_by!(key: params[:client_id])
  end

  def code
    @code ||= ::Oauth2Verifier.create! :client_application => app,
                                       :user               => @user,
                                       :scope              => @params[:scope],
                                       :callback_url       => @params[:redirect_uri]
  end

  def token
    @token ||= ::Oauth2Token.create! :client_application => app,
                                     :user               => @user,
                                     :scope              => @params[:scope],
                                     :callback_url       => @params[:redirect_uri]
  end

  def authorized?
    @authorized == true
  end

  def redirect_uri
    uri = base_uri
    if params[:response_type] == 'code'
      if uri.query
        uri.query << '&'
      else
        uri.query = ''
      end
      uri.query << encode_response
    else
      uri.fragment = encode_response
    end
    uri.to_s
  end

  def response
    r = {state: params[:state]}
    r[:error] = 'access_denied' unless authorized?
    case params[:response_type]
      when 'code'
        r[:code] = code.token
      when 'token'
        r[:access_token] = token.token
      else
        r[:error] = 'unsupported_response_type'
    end
    r
  end

  def encode_response
    response.map do |k, v|
      k && v && [CGI.escape(k.to_s), CGI.escape(v)].join("=")
    end * "&"
  end

  protected

  def base_uri
    URI.parse(params[:redirect_uri] || app.callback_url)
  end
end
