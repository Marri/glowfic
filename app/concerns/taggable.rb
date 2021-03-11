module Taggable
  private

  def process_tags(klass, obj_param:, id_param:)
    # fetch and clean tag ids
    ids = params.fetch(obj_param, {}).fetch(id_param, [])
    ids = ids.reject(&:blank?).map(&:to_s)
    return [] unless ids.present?

    # store formatted for creation-order sorting later
    match_ids = ids.map { |id| id.start_with?('_') ? id.upcase[1..-1].strip : id }

    # separate existing tags from new tags which start with _
    new_names = ids.select { |id| id.start_with?('_') }
    existing_tags = klass.where(id: (ids - new_names))
    new_names.map! { |name| name[1..-1].strip }

    # locate anything that already exists with the same name (locale unfriendly) and substitute it
    matched_new_tags = klass.where(name: new_names)
    matched_new_names = matched_new_tags.map { |tag| tag.name.upcase }
    new_names.reject! { |name| matched_new_names.include?(name.upcase) }

    # create anything case-insensitively (locale unfriendly) unique that remains
    new_names = new_names.uniq(&:upcase)
    new_tags = new_names.map { |name| klass.new(user: current_user, name: name) }

    # consolidate, sort and purge duplicates (locale unfriendly)
    all_tags = existing_tags + matched_new_tags + new_tags
    all_tags.sort_by! do |tag|
      match_ids.index(tag.name.upcase) || match_ids.index(tag.id.to_s)
    end
    all_tags.uniq { |tag| tag.name.upcase }
  end
end
