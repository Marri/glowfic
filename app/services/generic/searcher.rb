class Generic::Searcher < Object
  extend ActiveModel::Translation
  extend ActiveModel::Validations

  attr_accessor :name
  attr_reader   :errors, :templates, :users

  def initialize(search, templates: [], users: [])
    @search_results = search
    @templates = templates
    @users = users
    @errors = ActiveModel::Errors.new(self)
  end

  private

  def search_templates(template_id)
    template = Template.find_by(id: template_id)
    if template.present?
      if @users.blank? || template.user_id == @users.first.id
        @templates = [template]
        if @search_results.has_attribute?(:template_id)
          @search_results = @search_results.where(template_id: template.id)
        else
          character_ids = Character.where(template_id: template.id).pluck(:id)
          @search_results = @search_results.where(character_id: character_ids)
        end
      else
        errors.add(:base, "The specified author and template do not match; template filter will be ignored.")
        @templates = []
      end
    else
      errors.add(:template, "could not be found.")
      @templates = []
    end
  end

  def select_templates(user_id)
    @templates = Template.where(user_id: user_id).ordered.limit(25)
  end
end
