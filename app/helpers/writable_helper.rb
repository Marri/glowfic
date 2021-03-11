module WritableHelper
  def unread_warning
    return unless @replies.present?
    return if @replies.total_pages == page
    'You are not on the latest page of the thread ' + \
    content_tag(:a, '(View unread)', href: unread_path(@post), class: 'unread-warning') + ' ' + \
    content_tag(:a, '(New tab)', href: unread_path(@post), class: 'unread-warning', target: '_blank')
  end

  def unread_path(post, **kwargs)
    post_path(post, page: 'unread', anchor: 'unread', **kwargs)
  end

  def anchored_continuity_path(post)
    return continuity_path(post.board_id) unless post.section_id.present?
    continuity_path(post.board_id, anchor: "section-#{post.section_id}")
  end

  def dropdown_icons(item, galleries=nil)
    icons = []
    selected_id = nil

    if item.character
      icons = if galleries.present?
        galleries.map(&:icons).flatten
      else
        item.character.icons
      end
      icons |= [item.character.default_icon] if item.character.default_icon
      icons |= [item.icon] if item.icon
      selected_id = item.icon_id
    elsif current_user.avatar
      icons = [current_user.avatar]
      selected_id = current_user.avatar_id
    end

    return '' unless icons.present?
    select_tag :icon_dropdown, options_for_select(icons.map{|i| [i.keyword, i.id]}, selected_id), prompt: "No Icon"
  end

  PRIVACY_MAP = {
    public: ['Public', 'world'],
    registered: ['Constellation Users', 'star'],
    access_list: ['Access List', 'group'],
    private: ['Private', 'lock'],
  }

  def privacy_state(privacy)
    privacy = privacy.to_sym
    privacy_icon(privacy, false) + ' ' + PRIVACY_MAP[privacy][0]
  end

  def privacy_icon(privacy, alt=true)
    name = PRIVACY_MAP[privacy][0]
    img = PRIVACY_MAP[privacy][1]
    text = alt ? name : ''
    image_tag("icons/#{img}.png", class: 'vmid', title: name, alt: text)
  end

  def menu_img
    return 'icons/menu.png' unless current_user.try(:layout).to_s.start_with?('starry')
    'icons/menugray.png'
  end

  def shortened_desc(desc, id)
    return sanitize_simple_link_text(desc) if desc.length <= 255
    sanitize_simple_link_text(desc[0...255]) +
      content_tag(:span, '... ', id: "dots-#{id}") +
      content_tag(:span, sanitize_simple_link_text(desc[255..-1]), class: 'hidden', id: "desc-#{id}") +
      content_tag(:a, 'more &raquo;'.html_safe, href: '#', id: "expanddesc-#{id}", class: 'expanddesc')
  end

  def post_or_reply_link(reply)
    return unless reply.id.present?
    post_or_reply_mem_link(id: reply.id, klass: reply.class)
  end

  def post_or_reply_mem_link(id: nil, klass: nil)
    return if id.nil?
    if klass == Reply
      reply_path(id, anchor: "reply-#{id}")
    else
      post_path(id)
    end
  end

  def has_edit_audits?(audits, written)
    return false unless written.id.present?
    if written.is_a?(Post)
      count = audits[:post]
    else
      count = audits.fetch(written.id, 0)
    end
    count > 1
  end
end
