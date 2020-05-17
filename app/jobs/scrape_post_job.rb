class ScrapePostJob < ApplicationJob
  queue_as :low

  def perform(params, user:)
    Resque.logger.debug "Starting scrape for #{params[:dreamwidth_url]}"
    scraper = PostScraper.new(params[:dreamwidth_url], board_id: params[:board_id], section_id: params[:section_id],
                              status: params[:status], threaded: params[:threaded])
    scraped_post = scraper.scrape
    if scraper.errors.present?
      self.class.handle_errors(scraper.errors, user: user, url: params[:dreamwidth_url])
    else
      Message.send_site_message(user.id, 'Post import succeeded', "Your post was successfully imported! #{self.class.view_post(scraped_post.id)}")
    end
  end

  def self.handle_errors(errors, url:, user:)
    Resque.logger.warn "Failed to import #{url}: #{errors.full_messages}"
    if user
      message = ["The url <a href='#{url}'>#{url}</a> could not be successfully scraped."]
      message += errors.full_messages
      Message.send_site_message(user.id, 'Post import failed', message.join(" "))
    end
  end

  def self.view_post(post_id)
    host = ENV['DOMAIN_NAME'] || 'localhost:3000'
    url = Rails.application.routes.url_helpers.post_url(post_id, host: host, protocol: 'https')
    "<a href='#{url}'>View it here</a>."
  end
end
