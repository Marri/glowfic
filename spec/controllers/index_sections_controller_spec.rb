RSpec.describe IndexSectionsController do
  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires permission" do
      user = create(:user)
      index = create(:index)
      expect(index.editable_by?(user)).to eq(false)
      login_as(user)

      get :new, params: { index_id: index.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to modify this index.")
    end

    it "requires index_id" do
      login
      get :new
      expect(response.status).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index could not be found.")
    end

    it "works with index_id" do
      index = create(:index)
      login_as(index.user)
      get :new, params: { index_id: index.id }
      expect(response).to have_http_status(200)
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires permission" do
      user = create(:user)
      index = create(:index)
      expect(index.editable_by?(user)).to eq(false)
      login_as(user)

      post :create, params: { index_section: {index_id: index.id} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to modify this index.")
    end

    it "requires valid section" do
      index = create(:index)
      login_as(index.user)
      post :create, params: { index_section: {index_id: index.id} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Index section could not be created because of the following problems:")
    end

    it "succeeds" do
      index = create(:index)
      login_as(index.user)
      section_name = 'ValidSection'
      post :create, params: { index_section: {index_id: index.id, name: section_name} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:success]).to eq("New section, #{section_name}, created for #{index.name}.")
      expect(assigns(:section).name).to eq(section_name)
    end
  end

  describe "GET show" do
    it "requires valid section" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index section could not be found.")
    end

    it "does not require login" do
      section = create(:index_section)
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
    end

    it "works with login" do
      login
      section = create(:index_section)
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid section" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index section could not be found.")
    end

    it "requires permission" do
      section = create(:index_section)
      login
      get :edit, params: { id: section.id }
      expect(response).to redirect_to(index_url(section.index))
      expect(flash[:error]).to eq("You do not have permission to modify this index.")
    end

    it "works" do
      section = create(:index_section)
      login_as(section.index.user)
      get :edit, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit Index Section: #{section.name}")
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires index permission" do
      user = create(:user)
      login_as(user)
      index_section = create(:index_section)
      expect(index_section.index).not_to be_editable_by(user)

      put :update, params: { id: index_section.id }
      expect(response).to redirect_to(index_url(index_section.index))
      expect(flash[:error]).to eq("You do not have permission to modify this index.")
    end

    it "requires valid params" do
      index_section = create(:index_section)
      login_as(index_section.index.user)
      put :update, params: { id: index_section.id, index_section: {name: ''} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Index section could not be updated because of the following problems:")
    end

    it "succeeds" do
      index_section = create(:index_section, name: 'TestSection1')
      login_as(index_section.index.user)
      section_name = 'TestSection2'
      put :update, params: { id: index_section.id, index_section: {name: section_name} }
      expect(response).to redirect_to(index_path(index_section.index))
      expect(index_section.reload.name).to eq(section_name)
      expect(flash[:success]).to eq("Index section updated.")
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid section" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index section could not be found.")
    end

    it "requires permission" do
      section = create(:index_section)
      login
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(index_url(section.index))
      expect(flash[:error]).to eq("You do not have permission to modify this index.")
    end

    it "works" do
      section = create(:index_section)
      login_as(section.index.user)
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(index_url(section.index))
      expect(flash[:success]).to eq("Index section deleted.")
      expect(IndexSection.find_by_id(section.id)).to be_nil
    end

    it "handles destroy failure" do
      section = create(:index_section)
      index = section.index
      login_as(index.user)
      expect_any_instance_of(IndexSection).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("Index section could not be deleted.")
      expect(index.reload.index_sections).to eq([section])
    end
  end
end
