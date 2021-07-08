class Generic::Service < Object
  extend ActiveModel::Naming
  extend ActiveModel::Translation
  extend ActiveModel::Validations

  attr_reader :errors, :model

  def initialize
    @errors = ActiveModel::Errors.new(self)
  end

  def has_error?(error, attribute=:base)
    return false unless @errors.key?(attribute)
    @errors.added?(attribute, error)
  end

  def has_any_error?(errors, attribute: :base)
    return false unless @errors.key?(attribute)
    errors.select! { |error| @errors.added?(attribute, error) }
    errors.present?
  end
end
