class PostScraper < Object
  attr_accessor :url, :post, :html_doc

  def initialize(url, board_id=nil, section_id=nil, status=nil, threaded_import=false, console_import=false, subject=nil)
    @board_id = board_id || Board::ID_SANDBOX
    @section_id = section_id
    @status = status || :complete
    url += (url.include?('?') ? '&' : '?') + 'style=site' unless url.include?('style=site')
    url += '&view=flat' unless url.include?('view=flat') || threaded_import
    @url = url
    @console_import = console_import
    @threaded_import = threaded_import # boolean
    @subject = subject
  end

  def scrape!
    @html_doc = doc_from_url(@url)

    Post.transaction do
      import_post_from_doc(@html_doc)
      import_replies_from_doc(@html_doc)
      links = page_links
      links.each_with_index do |link, i|
        logger.debug "Scraping '#{@post.subject}': page #{i+1}/#{links.count}"
        doc = doc_from_url(link)
        import_replies_from_doc(doc)
      end
      finalize_post_data
    end
    GenerateFlatPostJob.perform_later(@post.id)
    @post
  end

  # works as an alternative to scrape! when you want to scrape particular
  # top-level threads of a post sequentially
  # "threads" are URL permalinks to the threads to scrape, which it will scrape
  # in the given order
  def scrape_threads!(threads)
    raise RuntimeError.new('threaded_import must be true to use scrape_threads!') unless @threaded_import

    @html_doc = doc_from_url(@url)
    # if threads.blank?
    #   threads = top_level_comments(@html_doc)
    # end

    Post.transaction do
      import_post_from_doc(@html_doc)
      threads.each do |thread|
        @html_doc = doc_from_url(thread)
        import_replies_from_doc(@html_doc)
        links = page_links
        links.each_with_index do |link, i|
          logger.debug "Scraping '#{@post.subject}': page #{i+1}/#{links.count}"
          doc = doc_from_url(link)
          import_replies_from_doc(doc)
        end
      end
      finalize_post_data
    end
    GenerateFlatPostJob.perform_later(@post.id)
    @post
  end

  private

  def doc_from_url(url)
    # download URL, trying up to 3 times
    max_try = 3
    retried = 0

    begin
      sleep 0.25
      data = HTTParty.get(url).body
    rescue Net::OpenTimeout => e
      retried += 1
      if retried < max_try
        logger.debug "Failed to get #{url}: #{e.message}; retrying (tried #{retried} #{'time'.pluralize(retried)})"
        retry
      else
        logger.warn "Failed to get #{url}: #{e.message}"
        raise
      end
    end

    Nokogiri::HTML(data)
  end

  def page_links
    return threaded_page_links if @threaded_import
    links = @html_doc.at_css('.page-links')
    return [] if links.nil?
    links.css('a').map { |link| link.attribute('href').value }
  end

  def threaded_page_links
    # gets pages after the first page
    # does not work based on depths as sometimes mistakes over depth are made
    # during threading (two replies made on the same depth)
    comments = @html_doc.at_css('#comments').css('.comment-thread')
    # 0..24 are in full on the first page
    # fetch 25..49, …, on the other pages
    links = []
    index = 25
    while index < comments.count
      first_reply_in_batch = comments[index]
      url = first_reply_in_batch.at_css('.comment-title').at_css('a').attribute('href').value
      unless url[/(\?|&)style=site/]
        url_obj = URI.parse(url)
        url_obj.query += ('&' if url_obj.query.present?) + 'style=site'
        url = url_obj.to_s
      end
      links << url
      depth = first_reply_in_batch[:class][/comment-depth-\d+/].sub('comment-depth-', '').to_i

      # check for accidental comment at same depth, if so go mark it as a new page too
      next_comment = comments[index+1]
      if next_comment && next_comment[:class][/comment-depth-\d+/].sub('comment-depth-', '').to_i == depth
        index += 1
      else
        index += 25
      end
    end
    links
  end

  def import_post_from_doc(doc)
    subject = @subject || doc.at_css('.entry .entry-title').text.strip
    logger.info "Importing thread '#{subject}'"

    @post = Post.new
    @post.board_id = @board_id
    @post.section_id = @section_id
    @post.subject = subject
    @post.status = @status
    @post.is_import = true

    # detect already imported
    # skip if it's a threaded import, unless a subject was given manually
    if (@subject || !@threaded_import) && (subj_post = Post.find_by(subject: @post.subject, board_id: @board_id))
      raise AlreadyImportedError.new("This thread has already been imported", subj_post.id)
    end

    scraper = ReplyScraper.new(@post, console: @console_import)
    scraper.import(doc)
  end

  def import_replies_from_doc(doc)
    comments = if @threaded_import
      doc.at_css('#comments').css('.comment-thread').first(25).compact
    else
      doc.at_css('#comments').css('.comment-thread') # can't do 25 on non-threaded because single page is 50 per
    end

    comments.each do |comment|
      reply = @post.replies.new(skip_notify: true, skip_post_update: true, skip_regenerate: true, is_import: true)
      scraper = ReplyScraper.new(reply, console: @console_import)
      scraper.import(comment)
    end
  end

  def finalize_post_data
    @post.last_user_id = @reply.try(:user_id) || @post.user_id
    @post.last_reply_id = @reply.try(:id)
    @post.tagged_at = @reply.try(:created_at) || @post.created_at
    @post.authors_locked = true
    @post.save!
  end

  def logger
    Resque.logger
  end
end

class AlreadyImportedError < RuntimeError
  attr_reader :post_id
  def initialize(msg, post_id)
    @post_id = post_id
    super(msg)
  end
end
