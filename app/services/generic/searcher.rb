class Generic::Searcher < Object
  extend ActiveModel::Translation
  extend ActiveModel::Validations

  attr_accessor :name
  attr_reader   :errors

  def initialize(search)
    @search_results = search
    @errors = ActiveModel::Errors.new(self)
  end
end
