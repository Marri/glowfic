class PostScraper < Object
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

  def initialize(url, board_id=nil, section_id=nil, status=nil, threaded_import=false, console_import=false, subject=nil)
    @board_id = board_id || Board::ID_SANDBOX
    @section_id = section_id
    @status = status || Post.statuses[:complete]
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

    username = doc.at_css('.entry-poster b').inner_html
    img_url = doc.at_css('.entry .userpic img').try(:attribute, 'src').try(:value)
    img_keyword = doc.at_css('.entry .userpic img').try(:attribute, 'title').try(:value)
    created_at = doc.at_css('.entry .datetime').text
    content = doc.at_css('.entry-content').inner_html
    content = strip_content(content)

    @post = Post.new(board_id: @board_id, section_id: @section_id, status: @status, subject: subject, content: content)
    @post.written.content = content
    @post.created_at = @post.updated_at = @post.edited_at = @post.written.created_at = @post.written.updated_at = created_at
    @post.is_import = true

    # detect already imported
    # skip if it's a threaded import, unless a subject was given manually
    if (@subject || !@threaded_import) && (subj_post = Post.find_by(subject: @post.subject, board_id: @board_id))
      raise AlreadyImportedError.new("This thread has already been imported", subj_post.id)
    end

    set_from_username(@post.written, username)
    @post.character = @post.written.character
    @post.user = @post.written.user
    @post.last_user_id = @post.user_id

    set_from_icon(@post.written, img_url, img_keyword)
    @post.icon = @post.written.icon

    Audited.audit_class.as_user(@post.user) do
      @post.save!
    end
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

      @reply = Reply.new
      @reply.post = @post
      @reply.content = strip_content(content)
      @reply.created_at = @reply.updated_at = created_at

      set_from_username(@reply, username)
      set_from_icon(@reply, img_url, img_keyword)

      @reply.skip_notify = true
      @reply.skip_post_update = true
      @reply.skip_regenerate = true
      @reply.is_import = true
      Audited.audit_class.as_user(@reply.user) do
        @reply.save!
      end
    end
  end

  def finalize_post_data
    @post.last_user_id = @reply.try(:user_id) || @post.user_id
    @post.last_reply_id = @reply.try(:id)
    @post.tagged_at = @reply.try(:created_at) || @post.created_at
    @post.authors_locked = true
    @post.save!
  end

  def set_from_username(tag, username)
    if BASE_ACCOUNTS.key?(username)
      tag.user = User.find_by(username: BASE_ACCOUNTS[username])
      return
    end

    character = Character.find_by(screenname: username.tr("-", "_")) || Character.find_by(screenname: username.tr("_", "-"))
    unless character
      user = prompt_for_user(username)
      character = Character.create!(user: user, name: username, screenname: username)
      gallery = Gallery.create!(user: user, name: username)
      CharactersGallery.create!(character_id: character.id, gallery_id: gallery.id)
    end

    tag.character = character
    tag.user = character.user
  end

  def prompt_for_user(username)
    raise UnrecognizedUsernameError.new("Unrecognized username: #{username}") unless @console_import
    print('User ID or username for ' + username + '? ')
    input = STDIN.gets.chomp
    return User.find_by_id(input) if input.to_s == input.to_i.to_s
    User.where('lower(username) = ?', input.downcase).first
  end

  def set_from_icon(tag, url, keyword)
    return unless url

    url = 'https://v.dreamwidth.org' + url if url[0] == '/'
    host_url = url.gsub(/https?:\/\//, "")
    https_url = 'https://' + host_url
    icon = Icon.find_by(url: https_url)
    tag.icon = icon and return if icon

    end_index = keyword.index("(Default)").to_i - 1
    start_index = (keyword.index(':') || -1) + 1
    parsed_keyword = keyword[start_index..end_index].strip
    parsed_keyword = 'Default' if parsed_keyword.blank? && keyword.include?("(Default)")
    keyword = parsed_keyword

    if tag.character
      icon = tag.character.icons.where(keyword: keyword).first
      tag.icon = icon and return if icon

      # split out the last " (...)" from the keyword (which should be at the
      # very end), if applicable, for without_desc
      without_desc = nil
      if keyword.end_with?(')')
        lbracket = keyword.rindex(' (')
        if lbracket && lbracket > 0 # without_desc must be non-empty
          without_desc = keyword[0...lbracket]
          icon = tag.character.icons.where(keyword: without_desc).first
          tag.icon = icon and return if icon
        end
      end

      # kappa icon handling - icons are prefixed
      if tag.user_id == 3 && (spaceindex = keyword.index(" "))
        unprefixed = keyword.slice(spaceindex, keyword.length)
        icon = tag.character.icons.detect { |i| i.keyword.ends_with?(unprefixed) }
        tag.icon = icon and return if icon

        if without_desc
          unprefixed = without_desc.slice(spaceindex, without_desc.length)
          icon = tag.character.icons.detect { |i| i.keyword.ends_with?(unprefixed) }
          tag.icon = icon and return if icon
        end
      end
    end

    icon = Icon.create!(user: tag.user, url: https_url, keyword: keyword)
    tag.icon = icon
    return unless tag.character

    gallery = tag.character.galleries.first
    if gallery.nil?
      gallery = Gallery.create!(user: tag.user, name: tag.character.name)
      CharactersGallery.create!(character_id: tag.character.id, gallery_id: gallery.id)
    end
    gallery.icons << icon
  end

  def strip_content(content)
    return content unless content.ends_with?("</div>")
    index = content.index('edittime')
    content[0..index-13]
  end

  def logger
    Resque.logger
  end
end

class UnrecognizedUsernameError < RuntimeError
end

class AlreadyImportedError < RuntimeError
  attr_reader :post_id
  def initialize(msg, post_id)
    @post_id = post_id
    super(msg)
  end
end
