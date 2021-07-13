class BoardPresenter
  attr_reader :board

  def initialize(board)
    @board = board
  end

  def as_json(options={})
    return {} unless board
    board_json = board.as_json_without_presenter(only: [:id, :name])
    return board_json unless options[:include].present? && options[:include].include?(:board_sections)
    # TODO what if lots of sections?
    board_json.merge(board_sections: board.board_sections.ordered)
  end
end
