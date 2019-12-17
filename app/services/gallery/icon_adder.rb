class Gallery::IconAdder < Generic::Service
  attr_reader :icon_errors, :icons

  def initialize(gallery, user:, params:)
    @gallery = gallery
    @user = user
    @params = params
    @icon_errors = []
    super()
  end

  def assign_existing
    @errors.add(:gallery, "could not be found.") && return unless @gallery # gallery required for adding icons from other galleries

    icon_ids = @params[:image_ids].split(',').map(&:to_i).reject(&:zero?)
    icon_ids -= @gallery.icons.pluck(:id)
    icons = Icon.where(id: icon_ids, user_id: @user.id)
    icons.each { |icon| @gallery.icons << icon }
  end

  def create_new
    @icons = (@params[:icons] || []).reject { |icon| icon.values.all?(&:blank?) }
    @errors.add(:base, "You have to enter something.") && return if icons.empty?
    icons = validate_icons
    return if @errors.present?
    save_icons(icons)
  end

  def validate_icons
    icons = @icons.map.with_index { |icon, index| initialize_icon(icon, index) }
    @errors.add(:icons, "could not be saved.") if @icon_errors.present?
    @icons = [] if icons.empty?
    icons
  end

  def save_icons(icons)
    if icons.all?(&:save)
      icons.each { |icon| @gallery.icons << icon } if @gallery
      @success_message = "Icons saved successfully."
    else
      @errors.add(:icons, "could not be saved.")
    end
  end

  def initialize_icon(icon, index)
    icon = Icon.new(icon_params(icon.except('filename', 'file')))
    icon.user = @user
    unless icon.valid?
      @icons[index]['url'] = @icons[index]['s3_key'] = '' if icon.errors.messages[:url]&.include?('is invalid')
      @icon_errors += icon.errors.full_messages.map{|m| "Icon #{index+1}: "+m.downcase}
    end
    icon
  end

  def icon_params(paramset)
    paramset.permit(:url, :keyword, :credit, :s3_key)
  end
end
