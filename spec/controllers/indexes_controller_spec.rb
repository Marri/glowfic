RSpec.describe IndexesController do
  describe "GET index" do
    it "works logged out" do
      get :index
      expect(response).to have_http_status(200)
    end

    it "works logged in" do
      login
      get :index
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Indexes")
    end
  end

  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "works logged in" do
      login
      get :new
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("New Index")
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index" do
      login
      post :create, params: { index: {} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Index could not be created because of the following problems:")
    end

    it "succeeds" do
      login
      name = 'ValidSection'
      post :create, params: { index: {name: name} }
      expect(response).to redirect_to(index_url(assigns(:index)))
      expect(flash[:success]).to eq("Index created.")
      expect(assigns(:index).name).to eq(name)
    end
  end

  describe "GET show" do
    it "requires valid index" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq('Index could not be found.')
    end

    it "requires visible index" do
      index = create(:index, privacy: :private)
      get :show, params: { id: index.id }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq('You do not have permission to view this index.')
    end

    it "works logged out" do
      index = create(:index)
      get :show, params: { id: index.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(index.name)
    end

    it "works logged in" do
      index = create(:index, privacy: :private)
      login_as(index.user)
      get :show, params: { id: index.id }
      expect(response).to have_http_status(200)
    end

    it "orders sectionless posts correctly" do
      index = create(:index)
      post1 = create(:index_post, index: index)
      post2 = create(:index_post, index: index)
      post3 = create(:index_post, index: index)
      post2.update!(section_order: 0)
      post3.update!(section_order: 1)
      post1.update!(section_order: 2)
      get :show, params: { id: index.id }
      expect(assigns(:sectionless)).to eq([post2.post, post3.post, post1.post])
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq('Index could not be found.')
    end

    it "requires permission" do
      login
      index = create(:index)
      get :edit, params: { id: index.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq('You do not have permission to modify this index.')
    end

    it "works" do
      index = create(:index)
      login_as(index.user)
      get :edit, params: { id: index.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit Index: #{index.name}")
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq('Index could not be found.')
    end

    it "requires permission" do
      login
      index = create(:index)
      put :update, params: { id: index.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq('You do not have permission to modify this index.')
    end

    it "requires valid index params" do
      index = create(:index)
      login_as(index.user)
      put :update, params: { id: index.id, index: {name: ''} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Index could not be updated because of the following problems:")
    end

    it "succeeds" do
      index = create(:index)
      login_as(index.user)
      name = 'ValidSection' + index.name
      put :update, params: { id: index.id, index: {name: name} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:success]).to eq("Index updated.")
      expect(index.reload.name).to eq(name)
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq('Index could not be found.')
    end

    it "requires permission" do
      login
      index = create(:index)
      delete :destroy, params: { id: index.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq('You do not have permission to modify this index.')
    end

    it "works" do
      index = create(:index)
      login_as(index.user)
      delete :destroy, params: { id: index.id }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:success]).to eq("Index deleted.")
      expect(Index.find_by_id(index.id)).to be_nil
    end

    it "handles destroy failure" do
      index = create(:index)
      section = create(:index_section, index: index)
      login_as(index.user)
      expect_any_instance_of(Index).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: index.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("Index could not be deleted.")
      expect(section.reload.index).to eq(index)
    end
  end
end
