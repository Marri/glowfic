# frozen_string_literal: true
class SettingsController < TaggableController
  def index
    @settings = Setting::Searcher.new.search(name: params[:name], page: page)
    @post_counts = Post.visible_to(current_user).joins(setting_posts: :setting).where(setting_posts: {setting_id: @settings.map(&:id)})
    @post_counts = @post_counts.group('setting_posts.setting_id').count
    @page_title = 'Settings'
  end

  def edit
    super
    build_editor
  end

  def update
    @setting.assign_attributes(permitted_params)

    begin
      Setting.transaction do
        @setting.parent_settings = process_tags(Setting, obj_param: :setting, id_param: :parent_setting_ids)
        @setting.save!
      end
    rescue ActiveRecord::RecordInvalid
      flash.now[:error] = {
        message: "Setting could not be saved because of the following problems:",
        array: @setting.errors.full_messages
      }
      @page_title = "Edit Setting: #{@setting.name}"
      build_editor
      render :edit
    else
      flash[:success] = "Setting saved!"
      redirect_to setting_path(@setting)
    end
  end

  def destroy
    if @setting.destroy
      flash[:success] = "Setting deleted."
      redirect_to settings_path(url_params)
    else
      flash[:error] = {
        message: "Setting could not be deleted.",
        array: @setting.errors.full_messages
      }
      redirect_to setting_path(@setting)
    end
  end

  private

  def find_model
    super(Setting, settings_path)
    @setting = @tag
  end

  def build_editor
    use_javascript('tags/edit')
  end
end
