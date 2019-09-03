class Generic::Service < Object
  extend ActiveModel::Naming
  extend ActiveModel::Translation

  attr_accessor :name
  attr_reader :errors

  def initialize
    @errors = ActiveModel::Errors.new(self)
  end

  alias :read_attribute_for_validation :send
end
