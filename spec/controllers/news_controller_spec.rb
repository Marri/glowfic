RSpec.describe NewsController do
  describe "GET index" do
    it "works logged out" do
      get :index
      expect(response).to have_http_status(200)
    end

    it "works logged in" do
      login
      get :index
      expect(response).to have_http_status(200)
    end

    it "only shows one news post" do
      create(:news)
      n2 = create(:news)
      get :index
      expect(assigns(:news).to_a).to eq([n2])
      expect(assigns(:news).total_pages).to eq(2)
    end

    it "marks the news post read" do
      user = create(:user)
      news = create(:news)
      expect(NewsView.find_by(user: user)).to be_nil

      login_as(user)
      get :index

      expect(NewsView.find_by(user: user).news).to eq(news)
    end
  end

  describe "GET new" do
    it "errors if logged out" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "errors if not staff" do
      login
      get :new
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to manage news posts.")
    end

    it "works for staff" do
      login_as(create(:mod_user))
      get :new
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq('Create News Post')
    end
  end

  describe "POST create" do
    it "errors if logged out" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "errors if not staff" do
      login
      post :create
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to manage news posts.")
    end

    it "errors without content" do
      login_as(create(:mod_user))
      post :create, params: {news: {content: ''}}
      expect(response).to render_template(:new)
      expect(assigns(:page_title)).to eq('Create News Post')
      expect(flash[:error][:message]).to eq("News post could not be created because of the following problems:")
    end

    it "works for staff" do
      login_as(create(:mod_user))
      expect {
        post :create, params: {news: {content: 'staff made this'}}
      }.to change { News.count }.by(1)
      expect(response).to redirect_to(news_index_url)
      expect(News.last.content).to eq('staff made this')
    end
  end

  describe "GET show" do
    it "errors without news post" do
      login_as(create(:admin_user))
      get :show, params: {id: -1}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("News post could not be found.")
    end

    it "works logged in" do
      n1 = create(:news)
      create(:news)
      n3 = create(:news)
      create(:news)
      n3.destroy!
      login
      get :show, params: {id: n1.id}
      expect(response).to redirect_to(news_index_url(page: 3))
    end

    it "works logged out" do
      news = create(:news)
      get :show, params: {id: news.id}
      expect(response).to redirect_to(news_index_url)
    end

    it "generates og data" do
      news = Timecop.freeze(Time.zone.local(2018, 12, 20)) { create(:news, content: "sample content") }
      create(:news)

      get :show, params: { id: news.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(news_index_path(page: 2))
      expect(meta_og[:title]).to eq('News Post for Dec 20, 2018')
      expect(meta_og[:description]).to eq('sample content')
    end
  end

  describe "GET edit" do
    it "errors if logged out" do
      get :edit, params: {id: -1}
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "errors without news post" do
      login_as(create(:admin_user))
      get :edit, params: {id: -1}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("News post could not be found.")
    end

    it "errors if not staff" do
      login
      get :edit, params: {id: create(:news).id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to manage news posts.")
    end

    it "errors if wrong mod" do
      news = create(:news)
      other_mod = create(:mod_user)
      login_as(other_mod)
      get :edit, params: {id: news.id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to modify this news post.")
    end

    it "works for admins" do
      news = create(:news)
      login_as(create(:admin_user))
      get :edit, params: {id: news.id}
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq('Edit News Post')
    end

    it "works for right mod" do
      news = create(:news)
      login_as(news.user)
      get :edit, params: {id: news.id}
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq('Edit News Post')
    end
  end

  describe "PATCH update" do
    it "errors if logged out" do
      patch :update, params: {id: -1}
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "errors without news post" do
      login_as(create(:admin_user))
      patch :update, params: {id: -1}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("News post could not be found.")
    end

    it "errors if not staff" do
      login
      patch :update, params: {id: create(:news).id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to manage news posts.")
    end

    it "errors if wrong mod" do
      news = create(:news)
      other_mod = create(:mod_user)
      login_as(other_mod)
      patch :update, params: {id: news.id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to modify this news post.")
    end

    it "errors without content" do
      news = create(:news)
      login_as(news.user)
      patch :update, params: {id: news.id, news: {content: ''}}
      expect(response).to render_template(:edit)
      expect(assigns(:page_title)).to eq('Edit News Post')
      expect(flash[:error][:message]).to eq("News post could not be updated because of the following problems:")
    end

    it "works for admins" do
      news = create(:news)
      login_as(create(:admin_user))
      patch :update, params: {id: news.id, news: {content: 'admin content'}}
      expect(response).to redirect_to(news_index_url)
      expect(news.reload.content).to eq('admin content')
    end

    it "works for right mod" do
      news = create(:news)
      login_as(news.user)
      patch :update, params: {id: news.id, news: {content: 'right mod content'}}
      expect(response).to redirect_to(news_index_url)
      expect(news.reload.content).to eq('right mod content')
    end
  end

  describe "DELETE destroy" do
    it "errors if logged out" do
      delete :destroy, params: {id: -1}
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "errors without news post" do
      login_as(create(:admin_user))
      delete :destroy, params: {id: -1}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("News post could not be found.")
    end

    it "errors if not staff" do
      login
      delete :destroy, params: {id: create(:news).id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to manage news posts.")
    end

    it "errors if wrong mod" do
      news = create(:news)
      other_mod = create(:mod_user)
      login_as(other_mod)
      delete :destroy, params: {id: news.id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("You do not have permission to modify this news post.")
    end

    it "errors if something fails" do
      news = create(:news)
      login_as(create(:admin_user))
      expect_any_instance_of(News).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: {id: news.id}
      expect(response).to redirect_to(news_index_url)
      expect(flash[:error]).to eq("News post could not be deleted.")
      expect(news.reload).not_to be_nil
    end

    it "works for admins" do
      news = create(:news)
      login_as(create(:admin_user))
      expect {
        delete :destroy, params: {id: news.id}
      }.to change { News.count }.by(-1)
      expect(News.find_by_id(news.id)).to be_nil
      expect(response).to redirect_to(news_index_url)
      expect(flash[:success]).to eq("News post deleted.")
    end

    it "works for right mod" do
      news = create(:news)
      login_as(news.user)
      expect {
        delete :destroy, params: {id: news.id}
      }.to change { News.count }.by(-1)
      expect(News.find_by_id(news.id)).to be_nil
      expect(response).to redirect_to(news_index_url)
      expect(flash[:success]).to eq("News post deleted.")
    end
  end
end
