class Api::V1::BoardSectionsController < Api::ApiController
  before_action :login_required

  resource_description do
    name 'Subcontinuities'
    description 'Viewing and editing subcontinuities'
  end

  api :POST, '/board_sections/reorder', 'Update the order of subcontinuities. This is an unstable feature, and may be moved or renamed; it should not be trusted.'
  error 401, "You must be logged in"
  error 403, "Board is not editable by the user"
  error 404, "Section IDs could not be found"
  error 422, "Invalid parameters provided"
  param :ordered_section_ids, Array, allow_blank: false
  def reorder
    section_ids = params[:ordered_section_ids].map(&:to_i).uniq
    sections = BoardSection.where(id: section_ids)
    sections_count = sections.count
    unless sections_count == section_ids.count
      missing_sections = section_ids - sections.pluck(:id)
      error = {message: "Some sections could not be found: #{missing_sections * ', '}"}
      render json: {errors: [error]}, status: :not_found and return
    end

    boards = Board.where(id: sections.select(:board_id).distinct.pluck(:board_id))
    unless boards.count == 1
      error = {message: 'Sections must be from one board'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    board = boards.first
    access_denied and return unless board.editable_by?(current_user)

    BoardSection.transaction do
      sections = sections.sort_by {|section| section_ids.index(section.id) }
      sections.each_with_index do |section, index|
        next if section.section_order == index
        section.update!(section_order: index)
      end

      other_sections = BoardSection.where(board_id: board.id).where.not(id: section_ids).ordered
      other_sections.each_with_index do |section, i|
        index = i + sections_count
        next if section.section_order == index
        section.update!(section_order: index)
      end
    end

    render json: {section_ids: BoardSection.where(board_id: board.id).ordered.pluck(:id)}
  end
end
