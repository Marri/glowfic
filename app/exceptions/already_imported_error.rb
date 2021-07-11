class AlreadyImportedError < PostImportError
  attr_reader :post_id
  def initialize(msg, post_id)
    @post_id = post_id
    host = ENV['DOMAIN_NAME'] || 'localhost:3000'
    super(msg + " as #{Rails.application.routes.url_helpers.post_url(post_id, host: host, protocol: 'https')}")
  end
end
