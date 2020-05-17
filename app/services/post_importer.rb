class PostImporter < Generic::Service
  attr_reader :url

  def initialize(url)
    @url = url
    super()
  end

  def import(params, user:)
    validate_url
    return false if @errors.present?
    validate_duplicate(params[:board_id]) unless params[:threaded]
    return false if @errors.present?
    validate_usernames
    return false if @errors.present?

    ScrapePostJob.perform_later(params, user: user)
  end

  def self.valid_dreamwidth_url?(url)
    # this is simply checking for a properly formatted Dreamwidth URL
    # errors when actually querying the URL are handled by ScrapePostJob
    return false if url.blank? || !url.include?('dreamwidth')
    parsed_url = URI.parse(url)
    parsed_url.host&.ends_with?('dreamwidth.org')
  rescue URI::InvalidURIError
    false
  end

  private

  def validate_url
    @errors.add(:url, :invalid) unless self.class.valid_dreamwidth_url?(@url)
  end

  def validate_duplicate(board_id)
    subject = dreamwidth_doc.at_css('.entry .entry-title').text.strip
    subj_post = Post.find_by(subject: subject, board_id: board_id)
    return unless subj_post
    @errors.add(:post, "has already been imported! #{ScrapePostJob.view_post(subj_post.id)}")
  end

  def validate_usernames
    missing_usernames = calculate_missing_usernames
    return unless missing_usernames.present?

    msg = "The following usernames were not recognized. "\
          "Please have the correct author create a character with the correct screenname, "\
          "or contact Marri if you wish to map a particular screenname to "\
          "'your base account posting without a character'."
    @errors.add(:base, msg)
    @errors.add(:username, missing_usernames)
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
