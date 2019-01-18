class Generic::Saver < Object
  def initialize(model, user:, params:, allowed_params: [])
    @user = user
    @params = params
    @model = model
    @allowed = allowed_params
  end

  def perform
    build
    save!
  end

  alias_method :create!, :perform
  alias_method :update!, :perform

  private

  def build
    @model.assign_attributes(permitted_params)
  end

  def save!
    @model.save!
  end

  def permitted_params
    @params.fetch(@model.class.name.underscore.to_sym, {}).permit(@allowed)
  end
end