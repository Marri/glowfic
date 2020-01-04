class Tag::Processer < Object
  def initialize(ids, klass:, user:)
    # clean tag ids
    @ids = ids.reject(&:blank?).map(&:to_s)
    @klass = klass
    @user = user
    @tags = []
  end

  def process
    return [] unless @ids.present?

    # separate existing tags from new tags which start with _
    new_names = split

    # locate anything that already exists with the same name (locale unfriendly) and substitute it
    new_names = find_existing(new_names)

    # create anything case-insensitively (locale unfriendly) unique that remains
    @tags += create_new(new_names)

    # sort and purge duplicates (locale unfriendly)
    sort

    @tags
  end

  private

  def split
    new_names = @ids.select { |id| id.start_with?('_') }
    @tags += @klass.where(id: (@ids - new_names))
    new_names.map { |name| name[1..-1].strip }
  end

  def find_existing(new_names)
    matched_new_tags = @klass.where(name: new_names)
    matched_new_names = matched_new_tags.map { |tag| tag.name.upcase }
    @tags += matched_new_tags
    new_names.reject { |name| matched_new_names.include?(name.upcase) }
  end

  def create_new(new_names)
    new_names = new_names.uniq(&:upcase)
    new_names.map { |name| @klass.new(user: @user, name: name) }
  end

  def sort
    match_ids = @ids.map { |id| id.start_with?('_') ? id.upcase[1..-1].strip : id } # for creation-order sorting
    @tags.sort_by! { |tag| match_ids.index(tag.name.upcase) || match_ids.index(tag.id.to_s) }
    @tags.uniq { |tag| tag.name.upcase }
  end
end
