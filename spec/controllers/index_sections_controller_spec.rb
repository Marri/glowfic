RSpec.describe IndexSectionsController do
  describe "GET new" do
    let(:index) { create(:index) }

    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires permission" do
      login
      get :new, params: { index_id: index.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "requires index_id" do
      login
      get :new
      expect(response.status).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index could not be found.")
    end

    it "works with index_id" do
      login_as(index.user)
      get :new, params: { index_id: index.id }
      expect(response).to have_http_status(200)
    end
  end

  describe "POST create" do
    let(:index) { create(:index) }

    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires permission" do
      login
      post :create, params: { index_section: {index_id: index.id} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "requires valid section" do
      login_as(index.user)
      post :create, params: { index_section: {index_id: index.id} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Index section could not be created.")
    end

    it "succeeds" do
      login_as(index.user)
      section_name = 'ValidSection'
      post :create, params: { index_section: {index_id: index.id, name: section_name} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:success]).to eq("New section, #{section_name}, has successfully been created for #{index.name}.")
      expect(assigns(:section).name).to eq(section_name)
    end
  end

  describe "GET show" do
    let(:section) { create(:index_section) }

    it "requires valid section" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index section could not be found.")
    end

    it "does not require login" do
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
    end

    it "works with login" do
      login
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
    end
  end

  describe "GET edit" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:section) { create(:index_section, index: index) }

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
      login
      get :edit, params: { id: section.id }
      expect(response).to redirect_to(index_url(section.index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "works" do
      login_as(user)
      get :edit, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit Index Section: #{section.name}")
    end
  end

  describe "PUT update" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:index_section) { create(:index_section, index: index) }

    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires index permission" do
      login
      put :update, params: { id: index_section.id }
      expect(response).to redirect_to(index_url(index_section.index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "requires valid params" do
      login_as(user)
      put :update, params: { id: index_section.id, index_section: {name: ''} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Index section could not be saved because of the following problems:")
    end

    it "succeeds" do
      index_section = create(:index_section, name: 'TestSection1')
      login_as(index_section.index.user)
      section_name = 'TestSection2'
      put :update, params: { id: index_section.id, index_section: {name: section_name} }
      expect(response).to redirect_to(index_path(index_section.index))
      expect(index_section.reload.name).to eq(section_name)
      expect(flash[:success]).to eq("Index section saved!")
    end
  end

  describe "DELETE destroy" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:section) { create(:index_section, index: index) }

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
      login
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(index_url(section.index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "works" do
      login_as(user)
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(index_url(section.index))
      expect(flash[:success]).to eq("Index section deleted.")
      expect(IndexSection.find_by_id(section.id)).to be_nil
    end

    it "handles destroy failure" do
      login_as(user)
      expect_any_instance_of(IndexSection).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq({message: "Index section could not be deleted.", array: []})
      expect(index.reload.index_sections).to eq([section])
    end
  end
end
