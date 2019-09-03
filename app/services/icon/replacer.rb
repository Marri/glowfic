class Icon::Replacer < Generic::Replacer
  def initialize(icon)
    @icon = icon
    super()
  end

  def replace(params, user:)
    new_icon = check_target(params[:icon_dropdown], user: user)
    return if @errors

    wheres = {icon_id: @icon.id}
    wheres[:post_id] = params[:post_ids] if params[:post_ids].present?
    updates = {icon_id: new_icon.try(:id)}
    replace_jobs(wheres: wheres, updates: updates, post_ids: params[:post_ids])
  end

  private

  def find_alts
    if @icon.has_gallery?
      all_icons = @icon.galleries.flat_map(&:icons).uniq.compact
    else
      all_icons = @icon.user.galleryless_icons
    end
    all_icons -= [@icon]
    all_icons.sort_by{|i| i.keyword.downcase }
  end

  def find_posts
    super({icon_id: @icon.id})
  end

  def construct_gallery(no_icon_url)
    gallery = Hash[@alts.map { |i| [i.id, {url: i.url, keyword: i.keyword}] }]
    gallery[''] = {url: no_icon_url, keyword: 'No Icon'}
    gallery
  end

  def check_target(id, user:)
    @errors.add(:icon, "could not be found.") unless id.blank? || (new_icon = Icon.find_by(id: id))
    @errors.add(:icon, "is not yours.") if new_icon && new_icon.user_id != user.id
    new_icon
  end
end
