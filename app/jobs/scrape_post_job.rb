class ScrapePostJob < ApplicationJob
  queue_as :low

  def perform(url, board_id, section_id, status, threaded, importer_id)
    Resque.logger.debug "Starting scrape for #{url}"
    scraper = PostScraper.new(url, board_id, section_id, status, threaded)
    scraped_post = scraper.scrape!
    Notification.notify_user(User.find_by(id: importer_id), :import_success, post: scraped_post)
  end

  def self.notify_exception(exception, url, board_id, section_id, status, threaded, importer_id)
    message = exception.is_a?(AlreadyImportedError) ? "Already imported as #{exception.message}" : exception.message
    Resque.logger.warn "Failed to import #{url}: #{message}"
    importer = User.find_by_id(importer_id)
    super unless importer
    if exception.is_a?(AlreadyImportedError)
      Notification.notify_user(importer, :import_fail, post: Post.find_by(id: exception.message))
    else
      Notification.notify_user(importer, :import_fail, error: exception.message)
    end
    super
  end
end
