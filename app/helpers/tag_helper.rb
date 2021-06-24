module TagHelper
  def delete_path(tag)
    url_params = {}
    url_params[:page] = page if params[:page].present?
    url_params[:view] = @view if @view.present?
    tag_path(tag, url_params)
  end

  def tag_select(obj, form, assoc, opts={})
    attr_name = assoc.to_s.singularize + "_ids"
    preview_collection = instance_variable_get("@#{assoc}")

    collection = if preview_collection.nil? # if I used || it would skip []s
      obj.send(assoc) # form.object != obj
    else
      preview_collection
    end
    selected_ids = collection.map(&:name)

    form.select(
      attr_name,
      options_from_collection_for_select(collection, :name, :name, selected_ids),
      {},
      {multiple: true}.merge(opts),
    )
  end
end
