# frozen_string_literal: true
class IndexesController < GenericController
  before_action :editor_setup, only: :edit

  def index
    super
    @indexes = Index.order('id asc').paginate(per_page: 25, page: page)
  end

  def edit
    super
  end

  def show
    super
    @sectionless = @index.posts.where(index_posts: {index_section_id: nil}).ordered_by_index
    dbselect = ', index_posts.description as index_description, index_posts.id as index_post_id'
    @sectionless = posts_from_relation(@sectionless, with_pagination: false, select: dbselect)
  end

  private

  def set_params
    @index.user = current_user
  end

  def permitted_params
    params.fetch(:index, {}).permit(:name, :description, :privacy, :authors_locked)
  end

  def editor_setup
    use_javascript('posts/index_edit')
    @index_sections = @index.index_sections.ordered
    @unsectioned_posts = @index.posts.where(index_posts: {index_section_id: nil})
    @unsectioned_posts = @unsectioned_posts.select("posts.*, index_posts.id as index_post_id, index_posts.section_order as section_order")
    @unsectioned_posts = @unsectioned_posts.order('index_posts.section_order ASC')
  end
end
