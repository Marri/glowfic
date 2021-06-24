class Tag::List < Array
  def initialize(list=[])
    super
    return if self == []
    clean_tags!
  end

  private

  def clean_tags!
    reject!(&:blank?)
    map!(&:to_s)
    map! { |name| name.start_with?('_') ? name[1..] : name }
    uniq!(&:downcase)
  end
end
