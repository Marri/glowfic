RSpec.describe IndexPostsController do
  describe "GET new" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }

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
      login_as(user)
      get :new, params: { index_id: index.id }
      expect(response).to have_http_status(200)
    end
  end

  describe "POST create" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }

    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires permission" do
      login
      post :create, params: { index_post: {index_id: index.id} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "requires valid post" do
      section = create(:index_section)
      login_as(user)
      post :create, params: { index_post: {index_id: index.id, index_section_id: section.id } }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Post could not be added to index.")
    end

    it "succeeds" do
      add_post = create(:post)
      login_as(user)
      post :create, params: { index_post: { index_id: index.id, post_id: add_post.id } }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:success]).to eq("Post added to index!")
    end
  end

  describe "GET edit" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:index_post) { create(:index_post, index: index) }

    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index post" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index post could not be found.")
    end

    it "requires permission" do
      login
      get :edit, params: { id: index_post.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "works" do
      login_as(user)
      get :edit, params: { id: index_post.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit Post in Index")
    end
  end

  describe "PATCH update" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:index_post) { create(:index_post, index: index) }

    it "requires login" do
      patch :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index post" do
      login
      patch :update, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index post could not be found.")
    end

    it "requires permission" do
      login
      patch :update, params: { id: index_post.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "requires valid params" do
      login_as(user)
      patch :update, params: { id: index_post.id, index_post: {post_id: nil} }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit Post in Index")
      expect(flash[:error][:message]).to eq("Index could not be saved")
    end

    it "works" do
      login_as(user)
      expect(index_post.description).to be_nil
      patch :update, params: { id: index_post.id, index_post: {description: 'some text'} }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:success]).to eq("Index post has been updated.")
      expect(index_post.reload.description).to eq('some text')
    end
  end

  describe "DELETE destroy" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:index_post) { create(:index_post, index: index) }

    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid index post" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(indexes_url)
      expect(flash[:error]).to eq("Index post could not be found.")
    end

    it "requires permission" do
      login
      delete :destroy, params: { id: index_post.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq("You do not have permission to edit this index.")
    end

    it "works" do
      login_as(user)
      delete :destroy, params: { id: index_post.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:success]).to eq("Post removed from index.")
      expect(IndexPost.count).to eq(0)
    end

    it "handles destroy failure" do
      login_as(user)
      expect_any_instance_of(IndexPost).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: index_post.id }
      expect(response).to redirect_to(index_url(index))
      expect(flash[:error]).to eq({message: "Post could not be removed from index.", array: []})
      expect(index.reload.index_posts).to eq([index_post])
    end
  end
end
