class ReplyScraper < Object
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

  attr_reader :errors

  def initialize(reply, errors: ActiveModel::Errors.new(self), console: false)
    @reply = reply
    @errors = errors
    @console_import = console
  end

  def import(username:, img_url:, img_keyword:, content:, created_at:)
    @reply.created_at = @reply.updated_at = created_at
    @reply.content = strip_content(content)
    @reply.user = set_from_username(username)
    @reply.icon = set_from_icon(img_url, img_keyword) if img_url
    post_setup if @reply.is_a? Post
    Audited.audit_class.as_user(@reply.user) do
      @reply.save!
    end
  end

  private

  def post_setup
    @reply.last_user_id = @reply.user_id
    @reply.edited_at = @reply.created_at
  end

  def set_from_username(username)
    return User.find_by(username: BASE_ACCOUNTS[username]) if BASE_ACCOUNTS.key?(username)

    character = Character.find_by(screenname: [username.tr("-", "_"), username.tr("_", "-")])
    unless character
      user = prompt_for_user(username)
      character = Character.create!(user: user, name: username, screenname: username)
      gallery = Gallery.create!(user: user, name: username)
      CharactersGallery.create!(character_id: character.id, gallery_id: gallery.id)
    end

    @reply.character = character
    character.user
  end

  def prompt_for_user(username)
    if @console_import
      print("User ID or username for #{username}? ")
      input = STDIN.gets.chomp
      return User.find_by(id: input) if input.to_s == input.to_i.to_s
      User.find_by('lower(username) = ?', input.downcase)
    else
      @errors.add(:base, "Unrecognized username: #{username}")
      raise ActiveRecord::Rollback
    end
  end

  def set_from_icon(url, keyword)
    url = icon_url(url)
    icon = Icon.find_by(url: url)
    return icon if icon

    keyword = parse_keyword(keyword)

    if @reply.character
      icon = @reply.character.icons.find_by(keyword: keyword)
      icon ||= clean_keyword(keyword)
      return icon if icon
    end

    create_icon(url, keyword)
  end

  def icon_url(url)
    uri = URI(url)
    uri.host ||= 'v.dreamwidth.org'
    uri.to_s
  end

  def parse_keyword(keyword)
    end_index = keyword.index("(Default)").to_i - 1
    start_index = (keyword.index(':') || -1) + 1
    parsed_keyword = keyword[start_index..end_index].strip
    parsed_keyword = 'Default' if parsed_keyword.blank? && keyword.include?("(Default)")
    parsed_keyword
  end

  def clean_keyword(keyword)
    # split out the last " (...)" from the keyword (which should be at the
    # very end), if applicable, for without_desc
    without_desc = nil
    if keyword.end_with?(')')
      lbracket = keyword.rindex(' (')
      if lbracket && lbracket > 0 # without_desc must be non-empty
        without_desc = keyword[0...lbracket]
        icon = @reply.character.icons.find_by(keyword: without_desc)
      end
    end
    icon ||= kappa_keyword(keyword, without_desc)
    icon
  end

  def kappa_keyword(keyword, without_desc)
    # kappa icon handling - icons are prefixed
    if @reply.user_id == 3 && (spaceindex = keyword.index(" "))
      unprefixed = keyword[spaceindex..-1]
      icon = @reply.character.icons.detect { |i| i.keyword.ends_with?(unprefixed) }
      icon ||= @reply.character.icons.detect { |i| i.keyword.ends_with?(without_desc[spaceindex..-1]) } if without_desc
    end
    icon
  end

  def create_icon(https_url, keyword)
    icon = Icon.create!(user: @reply.user, url: https_url, keyword: keyword)
    return icon unless @reply.character

    gallery = @reply.character.galleries.first
    if gallery.nil?
      gallery = Gallery.create!(user: @reply.user, name: @reply.character.name)
      CharactersGallery.create!(character_id: @reply.character.id, gallery_id: gallery.id)
    end
    gallery.icons << icon
    icon
  end

  def strip_content(content)
    return content unless content.ends_with?("</div>")
    index = content.index('edittime')
    content[0..index-13]
  end
end
