module Orderable
  extend ActiveSupport::Concern

  included do
    before_save :autofill_order
    after_save :reorder_others_after
    after_destroy :reorder_others_before

    scope :ordered_manually, -> { order('section_order asc') } unless respond_to?(:ordered_manually)

    def order
      section_order
    end

    def order=(val)
      self.section_order = val
    end

    private

    def reorder_others(is_after)
      return unless destroyed? || order_change?(is_after)

      if has_attribute?(:board_id) # all indexes are ordered
        board_checking_id = is_after ? board_id_before_last_save : board_id_was
        board_checking = Board.find_by_id(board_checking_id) || board
        return unless board_checking.ordered?
      end

      other_where = Hash[ordered_attributes.map do |atr|
        [atr, is_after ? attribute_before_last_save(atr) : attribute_was(atr)]
      end]
      others = self.class.where(other_where).ordered_manually
      return unless others.present?

      others.each_with_index do |other, index|
        next if other.order == index
        other.order = index
        other.save!
      end
    end

    def reorder_others_after
      reorder_others(true)
    end

    def reorder_others_before
      reorder_others(false)
    end

    def autofill_order
      return unless new_record? || order_change?(false)
      return if new_record? && self.order.present?
      self.order = ordered_items.count
    end

    def order_change?(is_after)
      return if new_record? # otherwise we will reorder on create
      ordered_attributes.any? do |atr|
        is_after ? saved_change_to_attribute?(atr) : attribute_changed?(atr)
      end
    end

    def ordered_items
      where_attr = Hash[ordered_attributes.map { |a| [a, self[a]] }]
      self.class.where(where_attr)
    end
  end
end
