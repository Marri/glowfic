# include Presentable in a model Model to have it automatically use app/presenters/ModelPresenter.rb to generate its JSON.
#
# Can safely be included on classes with no presenter file;
# it will fall back to the default / inherited as_json method.
#
# Limitations:
# - Presenter must have an initializer that takes the model as an argument
# - Presenter must implement as_json(options={})
# - If the class Model implements its own as_json method, that will override the presenter
#   but can access the presenter as_json through super (even if the presenter is included _afterwards_)

module Presents
  def as_json(options={})
    return super(options) if options.delete(:without_presenter)
    begin
      presenter = "#{self.class.name}Presenter".constantize
    rescue NameError
      super(options)
    else
      presenter.new(self).as_json(options)
    end
  end

  def as_json_without_presenter(options={})
    as_json(options.merge(without_presenter: true))
  end
end

module Presentable
  extend ActiveSupport::Concern

  included do
    prepend Presents
  end
end
