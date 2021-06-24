class PostImporter < Object
  def initialize(url)
    @url = url
  end

  def import(board_id, importer_id, section_id: nil, status: Post.statuses[:complete], threaded: false)
    validate_url!
    validate_duplicate!(board_id) unless threaded
    validate_usernames!

    # note that the arg order for this import method does not match the order of ScrapePostJob
    ScrapePostJob.perform_later(@url, board_id, section_id, status, threaded, importer_id)
  end

  def self.valid_dreamwidth_url?(url)
    # this is simply checking for a properly formatted Dreamwidth URL
    # errors when actually querying the URL are handled by ScrapePostJob
    return false if url.blank?
    return false unless url.include?('dreamwidth')
    parsed_url = URI.parse(url)
    return false unless parsed_url.host
    parsed_url.host.ends_with?('dreamwidth.org')
  rescue URI::InvalidURIError
    false
  end

  private

  def validate_url!
    raise InvalidDreamwidthURL.new('Invalid URL provided.') unless self.class.valid_dreamwidth_url?(@url)
  end

  def validate_duplicate!(board_id)
    subject = dreamwidth_doc.at_css('.entry .entry-title').text.strip
    subj_post = Post.where(subject: subject, board_id: board_id).first
    return unless subj_post
    raise AlreadyImported.new("This thread has already been imported! " + ScrapePostJob.view_post(subj_post.id))
  end

  def validate_usernames!
    missing_usernames = calculate_missing_usernames
    return unless missing_usernames.present?

    msg = "The following usernames were not recognized. "\
          "Please have the correct author create a character with the correct screenname, "\
          "or contact Marri if you wish to map a particular screenname to "\
          "'your base account posting without a character'."
    raise MissingUsernames.new(msg, missing_usernames)
  end

  def calculate_missing_usernames
    usernames = dreamwidth_doc.css('.poster span.ljuser b').map(&:text).uniq
    usernames -= ReplyScraper::BASE_ACCOUNTS.keys
    poster_names = dreamwidth_doc.css('.entry-poster span.ljuser b')
    usernames -= [poster_names.last.text] if poster_names.count > 1
    usernames -= Character.where(screenname: usernames).pluck(:screenname)
    dashed = usernames.map { |u| u.tr("_", "-")}
    usernames - Character.where(screenname: dashed).pluck(:screenname).map { |u| u.tr('-', '_') }
  end

  def dreamwidth_doc
    return @dreamwidth_doc if @dreamwidth_doc.present?
    data = HTTParty.get(@url).body
    Rails.logger.debug "Downloaded #{@url} for scraping"
    @dreamwidth_doc = Nokogiri::HTML(data)
  end
end

class PostImportError < ApiError; end
class MissingUsernames < PostImportError; end
class AlreadyImported < PostImportError; end
class InvalidDreamwidthURL < PostImportError; end
