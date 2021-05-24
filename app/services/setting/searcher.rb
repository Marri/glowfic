class Setting::Searcher < Object
  def initialize
    @qs = Setting.ordered_by_name.select('settings.*')
  end

  def search(name: nil, page: 1)
    @qs = @qs.where('name LIKE ?', "%#{name}%") if name.present?
    @qs.includes(:user).with_character_counts.paginate(page: page)
  end
end
