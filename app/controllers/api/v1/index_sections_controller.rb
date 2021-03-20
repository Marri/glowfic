class Api::V1::IndexSectionsController < Api::ApiController
  before_action :login_required

  resource_description do
    name 'Index Sections'
    description 'Viewing and editing index sections'
  end

  api :POST, '/index_sections/reorder', 'Update the order of index sections. This is an unstable feature, and may be moved or renamed; it should not be trusted.'
  error 401, "You must be logged in"
  error 403, "Index is not editable by the user"
  error 404, "Section IDs could not be found"
  error 422, "Invalid parameters provided"
  param :ordered_section_ids, Array, allow_blank: false
  def reorder
    section_ids = params[:ordered_section_ids].map(&:to_i).uniq
    sections = IndexSection.where(id: section_ids)
    sections_count = sections.count
    unless sections_count == section_ids.count
      missing_sections = section_ids - sections.pluck(:id)
      error = {message: "Some sections could not be found: #{missing_sections * ', '}"}
      render json: {errors: [error]}, status: :not_found and return
    end

    indexes = Index.where(id: sections.select(:index_id).distinct.pluck(:index_id))
    unless indexes.count == 1
      error = {message: 'Sections must be from one index'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    index = indexes.first
    access_denied and return unless index.editable_by?(current_user)

    IndexSection.transaction do
      sections = sections.sort_by {|section| section_ids.index(section.id) }
      sections.each_with_index do |section, i|
        next if section.section_order == i
        section.update!(section_order: i)
      end

      other_sections = IndexSection.where(index_id: index.id).where.not(id: section_ids).ordered
      other_sections.each_with_index do |section, j|
        order = j + sections_count
        next if section.section_order == order
        section.update!(section_order: order)
      end
    end

    render json: {section_ids: IndexSection.where(index_id: index.id).ordered.pluck(:id)}
  end
end
