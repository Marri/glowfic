module Taggable
  private

  def process_tags(klass, obj_param, id_param)
    ids = params.fetch(obj_param, {}).fetch(id_param, [])
    processer = Tag::Processer.new(ids, klass: klass, user: current_user)
    processer.process
  end
end
