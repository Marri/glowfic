module ApplicationHelper
  ICON = 'icon'.freeze
  NO_ICON = 'No Icon'.freeze
  NO_ICON_URL = 'icons/no-icon.png'.freeze
  TIME_FORMAT = '%b %d, %Y %l:%M %p'.freeze
  CHAR_ICON = 'char-access-icon pointer'.freeze
  CHAR_ICON_FAKE = 'char-access-icon char-access-fake pointer'.freeze

  def icon_tag(icon, **args)
    return '' if icon.nil?
    icon_mem_tag(icon.url, icon.keyword, **args)
  end

  def icon_mem_tag(url, keyword, **args)
    return '' if url.nil?
    klass = ICON
    klass += ' pointer' if args.delete(:pointer)
    if (supplied_class = args.delete(:class))
      klass += ' ' + supplied_class
    end

    image_tag url, {alt: keyword, title: keyword, class: klass}.merge(**args)
  end

  def no_icon_tag(**args)
    icon_mem_tag(NO_ICON_URL, NO_ICON, **args)
  end

  def loading_tag(**args)
    klass = 'vmid loading-icon'
    klass += ' ' + args[:class] if args[:class]
    image_tag 'icons/loading.gif', title: 'Loading...', class: klass, alt: '...', id: args[:id]
  end

  def quick_switch_tag(image_url, short_text, hover_name, char_id)
    if image_url.nil?
      return content_tag :div, short_text, class: CHAR_ICON_FAKE, title: hover_name, data: { character_id: char_id }
    end
    image_tag image_url, class: CHAR_ICON, alt: hover_name, title: hover_name, data: { character_id: char_id }
  end

  def user_icon_tag(user)
    quick_switch_tag(user.avatar.try(:url), user.username[0..1], user.username, '')
  end

  def character_icon_tag(character)
    quick_switch_tag(character.default_icon.try(:url), character.name[0..1], character.selector_name, character.id)
  end

  def swap_icon_url
    return 'icons/swap.png' unless current_user.try(:layout)
    return 'icons/swap.png' unless current_user.layout.start_with?('starry') || current_user.layout == 'dark'
    'icons/swapgray.png'
  end

  def pretty_time(time, format=nil)
    return unless time
    time.strftime(format || current_user.try(:time_display) || TIME_FORMAT)
  end

  def fun_name(user)
    return user.username unless user.moiety
    content_tag :span, user.username, style: 'font-weight: bold; color: #' + user.moiety
  end

  def color_block(user)
    return unless user.moiety
    content_tag :span, '█', style: 'cursor: default; color: #' + user.moiety, title: user.moiety_name
  end

  def unread_img
    return 'icons/note_go.png' unless current_user
    return 'icons/note_go.png' unless current_user.layout
    return 'icons/note_go.png' unless current_user.layout.include?('dark')
    'icons/bullet_go.png'
  end

  def lastlink_img
    return 'icons/note_go_strong.png' unless current_user
    return 'icons/note_go_strong.png' unless current_user.layout
    return 'icons/note_go_strong.png' unless current_user.layout.include?('dark')
    'icons/bullet_go_strong.png'
  end

  def path_for(obj, path)
    send (path + '_path') % obj.class.to_s.downcase, obj
  end

  def per_page_options(default=nil)
    default ||= per_page
    default = nil if default.to_i > 100

    options = [10, 25, 50, 100]
    options << default unless default.nil? || default.zero? || options.include?(default)
    options = Hash[*(options * 2).sort]
    options_for_select(options, default)
  end

  def timezone_options(default=nil)
    default ||= 'Eastern Time (US & Canada)'
    zones = ActiveSupport::TimeZone.all
    options_from_collection_for_select(zones, :name, :to_s, default)
  end

  def layout_options(default=nil)
    # Layout identifiers (values in this hash) are expected to not include spaces, so they are suitable as HTML classes for the TinyMCE editor
    layouts = {
      'Default': nil,
      'Dark': 'dark'.freeze,
      'Iconless': 'iconless'.freeze,
      'Starry': 'starry'.freeze,
      'Starry Dark' => 'starrydark'.freeze,
      'Starry Light' => 'starrylight'.freeze,
      'Monochrome': 'monochrome'.freeze,
      'Milky River' => 'river'.freeze,
    }
    options_for_select(layouts, default)
  end

  def time_display_options(default=nil)
    time_thing = Time.new(2016, 12, 25, 21, 34, 56) # Example time: "2016-12-25 21:34:56" (for unambiguous display purposes)
    time_display_list = [
      "%b %d, %Y %l:%M %p", "%b %d, %Y %H:%M", "%b %d, %Y %l:%M:%S %p", "%b %d, %Y %H:%M:%S",
      "%d %b %Y %l:%M %p", "%d %b %Y %H:%M", "%d %b %Y %l:%M:%S %p", "%d %b %Y %H:%M:%S",
      "%m-%d-%Y %l:%M %p", "%m-%d-%Y %H:%M", "%m-%d-%Y %l:%M:%S %p", "%m-%d-%Y %H:%M:%S",
      "%d-%m-%Y %l:%M %p", "%d-%m-%Y %H:%M", "%d-%m-%Y %l:%M:%S %p", "%d-%m-%Y %H:%M:%S",
      "%Y-%m-%d %l:%M %p", "%Y-%m-%d %H:%M", "%Y-%m-%d %l:%M:%S %p", "%Y-%m-%d %H:%M:%S"
    ]
    time_displays = Hash[time_display_list.map { |v| [time_thing.strftime(v), v] }]
    options_for_select(time_displays, default)
  end

  def sanitize_post_description(desc)
    Glowfic::Sanitizers.description(desc)
  end

  # modified version of split_paragraphs that doesn't mangle large breaks
  # https://apidock.com/rails/v4.2.7/ActionView/Helpers/TextHelper/split_paragraphs
  def split_paragraphs_largebreak(text)
    return [] if text.blank?
    text.to_str.gsub(/\r\n?/, "\n").split(/\n\n/).map! do |t|
      t.gsub!(/(^\n|[^\n]\n)(?=[^\n])/, '\1<br />') || t
    end
  end

  # modified version of simple_format that doesn't mangle large breaks
  # https://apidock.com/rails/ActionView/Helpers/TextHelper/simple_format
  def simple_format_largebreak(text, options = {})
    wrapper_tag = options.fetch(:wrapper_tag, :p)
    text = sanitize(text) if options.fetch(:sanitize, true)
    paragraphs = split_paragraphs_largebreak(text)

    if paragraphs.empty?
      content_tag(wrapper_tag, nil)
    else
      paragraphs.map! { |paragraph|
        if paragraph.empty?
          content_tag(wrapper_tag, '&nbsp;'.html_safe)
        else
          content_tag(wrapper_tag, raw(paragraph))
        end
      }.join("\n\n").html_safe
    end
  end

  P_TAG = /<p( [^>]*)?>/
  BR_TAG = /<br *\/?>/
  BLOCKQUOTE_QUICK_SEARCH = '<blockquote'.freeze
  BLOCKQUOTE_TAG = /<blockquote( |>)/
  LINEBREAK = /\r?\n/
  BR = '<br>'.freeze

  # specific blockquote handling is due to simple_format wanting to wrap a blockquote in a paragraph
  def sanitize_written_content(content)
    unless content[P_TAG] || content[BR_TAG]
      content = if content[BLOCKQUOTE_QUICK_SEARCH] && content[BLOCKQUOTE_TAG]
        content.gsub(LINEBREAK, BR)
      else
        simple_format_largebreak(content, sanitize: false)
      end
    end

    Glowfic::Sanitizers.written(content)
  end

  def breakable_text(text)
    return text if text.nil?
    h(text).gsub('_', '_<wbr>').html_safe
  end

  def post_privacy_settings
    { 'Public'              => Concealable::PUBLIC,
      'Constellation Users' => Concealable::REGISTERED,
      'Access List'         => Concealable::ACCESS_LIST,
      'Private'             => Concealable::PRIVATE }
  end

  def index_privacy_settings
    { 'Public'              => Concealable::PUBLIC,
      'Constellation Users' => Concealable::REGISTERED,
      'Private'             => Concealable::PRIVATE }
  end

  def unread_post?(post, unread_ids)
    return false unless post
    return false unless unread_ids
    unread_ids.include?(post.id)
  end

  def opened_post?(post, opened_ids)
    return false unless post
    return false unless opened_ids
    opened_ids.include?(post.id)
  end

  def message_sender(message)
    return message.sender_name if message.site_message?
    link_to(message.sender_name, user_path(message.sender))
  end

  def css_color_to_rgb(csscol)
    return unless csscol.match?(User::MOIETY_REGEX)
    # split the color into three groups, and process into the numeric values
    # "AB" is treated as a standard hex, "A" is treated as "AA"
    split_colors = csscol.chars.in_groups(3).map {|x| x.reduce(:+) }
    # "ABCDEF" -> ["AB", "CD", "EF"]
    split_colors.map do |val|
      val *= 2 if val.length == 1 # fix short colors, so e.g. "A" -> "AA"
      val.to_i(16) # convert to hex
      # -> [171, 205, 239] = R, G, B
    end
  end

  def rgb_to_lum(rgb)
    (rgb.max + rgb.min) / 255.0 / 2.0
  end

  # returns "moiety-light" if luminosity >= 75%
  # returns "moiety-dark" if luminosity <= 25%
  # returns nil if invalid moiety or 25% < lum(moiety) < 75%
  def moiety_class(moiety)
    rgb = css_color_to_rgb(moiety)
    if rgb
      lum = rgb_to_lum(rgb)
      if lum >= 0.75
        'moiety-light'.freeze
      elsif lum <= 0.25
        'moiety-dark'.freeze
      end
    end
  end
end
