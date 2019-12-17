class Character::Saver < Auditable::Saver
  attr_reader :character

  def initialize(character, user:, params:)
    super
    @character = character
    @settings = process_tags(Setting, :character, :setting_ids)
    @gallery_groups = process_tags(GalleryGroup, :character, :gallery_group_ids)
  end

  private

  def perform
    build_template
    save
  end

  def save
    Character.transaction do
      @character.assign_attributes(permitted_params)
      check_audit_comment
      raise ActiveRecord::Rollback if @errors
      @character.settings = process_tags(Setting, :character, :setting_ids)
      @character.gallery_groups = process_tags(GalleryGroup, :character, :gallery_group_ids)
      @character.save!
    end
  rescue ActiveRecord::RecordInvalid
    @errors.merge!(@character.errors)
  end

  def build_template
    return unless @params[:new_template].present? && @character.user == @user
    @character.build_template unless @character.template
    @character.template.user = @user
  end

  def process_tags(klass, obj_param, id_param)
    ids = @params.fetch(obj_param, {}).fetch(id_param, [])
    processer = Tag::Processer.new(ids, klass: klass, user: @user)
    processer.process
  end

  def permitted_params
    permitted = [
      :name,
      :template_name,
      :screenname,
      :template_id,
      :pb,
      :description,
      :audit_comment,
      ungrouped_gallery_ids: [],
    ]
    if @character.user == @user
      permitted.last[:template_attributes] = [:name, :id]
      permitted.insert(0, :default_icon_id)
    end
    @params.fetch(:character, {}).permit(permitted)
  end
end
