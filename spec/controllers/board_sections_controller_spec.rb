RSpec.describe BoardSectionsController do
  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires permission" do
      user = create(:user)
      board = create(:board)
      expect(board.editable_by?(user)).to eq(false)
      login_as(user)

      get :new, params: { board_id: board.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to modify this continuity.")
    end

    it "works with board_id" do
      board = create(:board)
      login_as(board.creator)
      get :new, params: { board_id: board.id }
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("New Section")
    end

    it "works without board_id" do
      login
      get :new
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("New Section")
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
      board = create(:board)
      expect(board.editable_by?(user)).to eq(false)
      login_as(user)

      post :create, params: { board_section: {board_id: board.id} }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to modify this continuity.")
    end

    it "requires valid section" do
      board = create(:board)
      login_as(board.creator)
      post :create, params: { board_section: {board_id: board.id} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Section could not be created because of the following problems:")
    end

    it "requires valid board for section" do
      board = create(:board)
      login_as(board.creator)
      post :create, params: { board_section: {name: 'fake'} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Section could not be created because of the following problems:")
    end

    it "succeeds" do
      board = create(:board)
      login_as(board.creator)
      section_name = 'ValidSection'
      post :create, params: { board_section: {board_id: board.id, name: section_name} }
      expect(response).to redirect_to(edit_continuity_url(board))
      expect(flash[:success]).to eq("New section, #{section_name}, created for #{board.name}.")
      expect(assigns(:board_section).name).to eq(section_name)
    end
  end

  describe "GET show" do
    it "requires valid section" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Section not found.")
    end

    it "does not require login" do
      section = create(:board_section)
      posts = Array.new(2) { create(:post, board: section.board, section: section) }
      create(:post)
      create(:post, board: section.board)
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
      expect(assigns(:posts)).to match_array(posts)
    end

    it "works with login" do
      login
      section = create(:board_section)
      posts = Array.new(2) { create(:post, board: section.board, section: section) }
      create(:post)
      create(:post, board: section.board)
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
      expect(assigns(:posts)).to match_array(posts)
    end

    it "orders posts correctly" do
      board = create(:board)
      section = create(:board_section, board: board)
      post5 = create(:post, board: board, section: section)
      post1 = create(:post, board: board, section: section)
      post4 = create(:post, board: board, section: section)
      post3 = create(:post, board: board, section: section)
      post2 = create(:post, board: board, section: section)
      post1.update!(section_order: 1)
      post2.update!(section_order: 2)
      post3.update!(section_order: 3)
      post4.update!(section_order: 4)
      post5.update!(section_order: 5)
      get :show, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq(section.name)
      expect(assigns(:posts)).to eq([post1, post2, post3, post4, post5])
    end

    it "calculates OpenGraph data" do
      user = create(:user, username: 'John Doe')
      board = create(:board, name: 'board', creator: user, writers: [create(:user, username: 'Jane Doe')])
      section = create(:board_section, name: 'section', board: board, description: "test description")
      create(:post, subject: 'title', user: user, board: board, section: section)
      get :show, params: { id: section.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(board_section_url(section))
      expect(meta_og[:title]).to eq('board » section')
      expect(meta_og[:description]).to eq("Jane Doe, John Doe – 1 post\ntest description")
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
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Section not found.")
    end

    it "requires permission" do
      section = create(:board_section)
      login
      get :edit, params: { id: section.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to modify this continuity.")
    end

    it "works" do
      section = create(:board_section)
      login_as(section.board.creator)
      get :edit, params: { id: section.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit #{section.name}")
      expect(assigns(:board_section)).to eq(section)
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires board permission" do
      user = create(:user)
      login_as(user)
      board_section = create(:board_section)
      expect(board_section.board).not_to be_editable_by(user)

      put :update, params: { id: board_section.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to modify this continuity.")
    end

    it "requires valid params" do
      board_section = create(:board_section)
      login_as(board_section.board.creator)
      put :update, params: { id: board_section.id, board_section: {name: ''} }
      expect(response).to have_http_status(200)
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Section could not be updated because of the following problems:")
    end

    it "succeeds" do
      board_section = create(:board_section, name: 'TestSection1')
      login_as(board_section.board.creator)
      section_name = 'TestSection2'
      put :update, params: { id: board_section.id, board_section: {name: section_name} }
      expect(response).to redirect_to(board_section_path(board_section))
      expect(board_section.reload.name).to eq(section_name)
      expect(flash[:success]).to eq("Section updated.")
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
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Section not found.")
    end

    it "requires permission" do
      section = create(:board_section)
      login
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to modify this continuity.")
    end

    it "works" do
      section = create(:board_section)
      login_as(section.board.creator)
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(edit_continuity_url(section.board))
      expect(flash[:success]).to eq("Section deleted.")
      expect(BoardSection.find_by_id(section.id)).to be_nil
    end

    it "handles destroy failure" do
      section = create(:board_section)
      post = create(:post, user: section.board.creator, board: section.board, section: section)
      login_as(section.board.creator)
      expect_any_instance_of(BoardSection).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: section.id }
      expect(response).to redirect_to(board_section_url(section))
      expect(flash[:error]).to eq("Section could not be deleted.")
      expect(post.reload.section).to eq(section)
    end
  end
end
