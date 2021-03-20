class Api::V1::IndexPostsController < Api::ApiController
  before_action :login_required
  resource_description do
    name 'Index Posts'
    description 'Viewing and editing index posts'
  end

  api :POST, '/index_posts/reorder', 'Update the order of posts. This is an unstable feature, and may be moved or renamed; it should not be trusted.'
  error 401, "You must be logged in"
  error 403, "Index is not editable by the user"
  error 404, "Post IDs could not be found"
  error 422, "Invalid parameters provided"
  param :ordered_post_ids, Array, allow_blank: false
  param :section_id, :number, required: false
  def reorder
    section_id = params[:section_id] ? params[:section_id].to_i : nil
    post_ids = params[:ordered_post_ids].map(&:to_i).uniq
    posts = IndexPost.where(id: post_ids)
    posts_count = posts.count
    unless posts_count == post_ids.count
      missing_posts = post_ids - posts.pluck(:id)
      error = {message: "Some posts could not be found: #{missing_posts * ', '}"}
      render json: {errors: [error]}, status: :not_found and return
    end

    indexes = Index.where(id: posts.select(:index_id).distinct.pluck(:index_id))
    unless indexes.count == 1
      error = {message: 'Posts must be from one index'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    index = indexes.first
    access_denied and return unless index.editable_by?(current_user)

    post_section_ids = posts.select(:index_section_id).distinct.pluck(:index_section_id)
    unless post_section_ids == [section_id] &&
      (section_id.nil? || IndexSection.where(id: section_id, index_id: index.id).exists?)
      error = {message: 'Posts must be from one specified section in the index, or no section'}
      render json: {errors: [error]}, status: :unprocessable_entity and return
    end

    IndexPost.transaction do
      posts = posts.sort_by {|post| post_ids.index(post.id) }
      posts.each_with_index do |post, i|
        next if post.section_order == i
        post.update!(section_order: i)
      end

      other_posts = IndexPost.where(index_id: index.id, index_section_id: section_id).where.not(id: post_ids).ordered_in_section
      other_posts.each_with_index do |post, i|
        pos = i + posts_count
        next if post.section_order == pos
        post.update!(section_order: pos)
      end
    end

    posts = IndexPost.where(index_id: index.id, index_section_id: section_id)
    render json: {post_ids: posts.ordered_in_section.pluck(:id)}
  end
end
