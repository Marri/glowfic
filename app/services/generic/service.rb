class Generic::Service < Object
  extend ActiveModel::Translation
  extend ActiveModel::Validations

  def initialize
    @errors = ActiveModel::Errors.new(self)
  end

  attr_reader :errors, :model
end
