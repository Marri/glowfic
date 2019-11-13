class PostScraper < Generic::Service
  SANDBOX_ID = 3
  BASE_ACCOUNTS = {
    'alicornucopia'      => 'Alicorn',
    'pythbox'            => 'Kappa',
    'lintamande'         => 'lintamande',
    'marrinikari'        => 'Marri',
    'peterxy'            => 'Pedro',
    'peterverse'         => 'Pedro',
    'curiousdiscoverer'  => 'CuriousDiscoverer',
    'aestrix'            => 'Aestrix',
    'unbitwise'          => 'Unbitwise',
    'erinflight'         => 'ErinFlight',
    'andaisq'            => 'andaisq',
    'rockeye-stonetoe'   => 'Rockeye',
    'rockeye_stonetoe'   => 'Rockeye',
    'maggie-of-the-owls' => 'MaggieoftheOwls',
    'maggie_of_the_owls' => 'MaggieoftheOwls', # have both - and _ versions cause Dreamwidth supports both
    'nemoconsequentiae'  => 'Nemo',
    'armokgob'           => 'Armok',
    'timepoof'           => 'Timepoof',
  }

  attr_accessor :url, :post, :html_doc

  def initialize(url, board_id: SANDBOX_ID, section_id: nil, status: Post.statuses[:complete], threaded: false, console: false, subject: nil)
    @board_id = board_id
    @section_id = section_id
    @status = status
    @url = clean_url(url)
    @console_import = console
    @threaded_import = threaded # boolean
    @subject = subject
    super()
  end

  def scrape!(threads=nil)
    @html_doc = doc_from_url(@url)

    Post.transaction do
      import_post_from_doc(@html_doc)
      if threads.present?
        threads.each do |thread|
          @html_doc = doc_from_url(thread)
          evaluate_links
        end
      else
        evaluate_links
      end
      finalize_post_data
    end
    return if @errors.present?
    GenerateFlatPostJob.perform_later(@post.id)
    @post
  end

  # works as an alternative to scrape! when you want to scrape particular
  # top-level threads of a post sequentially
  # "threads" are URL permalinks to the threads to scrape, which it will scrape
  # in the given order
  def scrape_threads!(threads)
    @errors.add(:base, 'threaded_import must be true to use scrape_threads!') && return unless @threaded_import
    scrape!(threads)
  end

  private

  def evaluate_links
    import_replies_from_doc(@html_doc)
    links = page_links
    links.each_with_index do |link, i|
      logger.debug "Scraping '#{@post.subject}': page #{i+1}/#{links.count}"
      doc = doc_from_url(link)
      import_replies_from_doc(doc)
    end
  end

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
      links << clean_url(url)
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

    username = doc.at_css('.entry-poster b').inner_html
    img_url = doc.at_css('.entry .userpic img').try(:attribute, 'src').try(:value)
    img_keyword = doc.at_css('.entry .userpic img').try(:attribute, 'title').try(:value)
    created_at = doc.at_css('.entry .datetime').text
    content = doc.at_css('.entry-content').inner_html

    # detect already imported
    # skip if it's a threaded import, unless a subject was given manually
    if (@subject || !@threaded_import) && (subj_post = Post.find_by(subject: subject, board_id: @board_id))
      @errors.add(:post, "was already imported! #{ScrapePostJob.view_post(subj_post.id)}")
      raise ActiveRecord::Rollback
    end

    @post = Post.new(board_id: @board_id, section_id: @section_id, subject: subject, status: @status, is_import: true)

    scraper = ReplyScraper.new(@post, errors: @errors)
    scraper.import(username: username, img_url: img_url, img_keyword: img_keyword, content: content, created_at: created_at)
  end

  def import_replies_from_doc(doc)
    comments = if @threaded_import
      doc.at_css('#comments').css('.comment-thread').first(25).compact
    else
      doc.at_css('#comments').css('.comment-thread') # can't do 25 on non-threaded because single page is 50 per
    end

    comments.each do |comment|
      content = comment.at_css('.comment-content').inner_html
      img_url = comment.at_css('.userpic img').try(:attribute, 'src').try(:value)
      img_keyword = comment.at_css('.userpic img').try(:attribute, 'title').try(:value)
      username = comment.at_css('.comment-poster b').inner_html
      created_at = comment.at_css('.datetime').text

      @reply = @post.replies.new(skip_notify: true, skip_post_update: true, skip_regenerate: true, is_import: true)
      scraper = ReplyScraper.new(@reply, errors: @errors)
      scraper.import(username: username, img_url: img_url, img_keyword: img_keyword, content: content, created_at: created_at)
    end
  end

  def finalize_post_data
    @post.last_user_id = @reply.try(:user_id) || @post.user_id
    @post.last_reply_id = @reply.try(:id)
    @post.tagged_at = @reply.try(:created_at) || @post.created_at
    @post.authors_locked = true
    @post.save!
  end

  def clean_url(url)
    uri = URI(url)
    query = Rack::Utils.parse_query(uri.query)
    return url if query['style'] == 'site' && (query['view'] = 'flat' || @threaded_import)
    query['style'] = 'site'
    query['view'] = 'flat' unless @threaded_import
    query = Rack::Utils.build_query(query)
    URI::HTTPS.build(host: uri.host, path: uri.path, fragment: uri.fragment, query: query).to_s
  end

  def logger
    Resque.logger
  end
end
