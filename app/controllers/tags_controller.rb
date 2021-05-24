# frozen_string_literal: true
class TagsController < TaggableController
  def index
    @tags = TagSearcher.new.search(tag_name: params[:name], tag_type: params[:view], page: page)
    @post_counts = Post.visible_to(current_user).joins(post_tags: :tag).where(post_tags: {tag_id: @tags.map(&:id)})
    @post_counts = @post_counts.group('post_tags.tag_id').count
    @view = params[:view]
    @page_title = @view.present? ? @view.titlecase.pluralize : 'Tags'
    @tag_options = (Tag::TYPES - ['GalleryGroup']).sort.reverse.index_by(&:titlecase)
    use_javascript('tags/index')
  rescue InvalidTagType => e
    flash[:error] = e.api_error
    redirect_to tags_path
  end

  def update
    if @tag.update(permitted_params)
      flash[:success] = "Tag saved!"
      redirect_to tag_path(@tag)
    else
      flash.now[:error] = {
        message: "Tag could not be saved because of the following problems:",
        array: @tag.errors.full_messages
      }
      @page_title = "Edit Tag: #{@tag.name}"
      render :edit
    end
  end

  def destroy
    if @tag.destroy
      flash[:success] = "Tag deleted."
      redirect_to tags_path(url_params)
    else
      flash[:error] = {
        message: "Tag could not be deleted.",
        array: @tag.errors.full_messages
      }
      redirect_to tag_path(@tag)
    end
  end

  private

  def find_model
    super(Tag, tags_path)
  end
end
