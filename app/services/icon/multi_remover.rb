class Icon::MultiRemover < Generic::Service
  attr_reader :gallery

  def perform(params, user:)
    @gallery = Gallery.find_by_id(params[:gallery_id])
    icon_ids = (params[:marked_ids] || []).map(&:to_i).reject(&:zero?)
    if icon_ids.empty? || (@icons = Icon.where(id: icon_ids, user_id: user.id)).empty?
      @errors.add(:base, "No icons selected.")
      return
    end

    if params[:gallery_delete]
      remove(user)
    else
      @icons.destroy_all
    end
  end

  def remove(user)
    @errors.add(:gallery, "could not be found.") unless @gallery
    @errors.add(:gallery, "is not yours.") if @gallery && @gallery.user_id != user.id
    return if @errors.present?
    @icons.each { |icon| @gallery.icons.destroy(icon) }
  end
end
