class Character::Searcher < Generic::Searcher
  def initialize(search=Character.unscoped, templates:, users: [])
    super
  end

  def search(params, page: 1)
    search_users(params[:author_id]) if params[:author_id].present?
    search_templates(params[:template_id]) if params[:template_id].present?
    search_names(params) if params[:name].present?
    select_templates(params[:author_id]) if params[:author_id].present? && params[:template_id].blank?
    @search_results.ordered.paginate(page: page, per_page: 25)
  end

  private

  def search_users(user_id)
    @users = User.active.where(id: user_id)
    if @users.present?
      @search_results = @search_results.where(user_id: user_id)
    else
      errors.add(:user, "could not be found.")
    end
  end

  def search_names(params)
    where_calc = []
    where_calc << "name LIKE ?" if params[:search_name].present?
    where_calc << "screenname LIKE ?" if params[:search_screenname].present?
    where_calc << "nickname LIKE ?" if params[:search_nickname].present?

    @search_results = @search_results.where(where_calc.join(' OR '), *(['%' + params[:name].to_s + '%'] * where_calc.length))
  end
end
