RSpec.describe BoardsController do
  include ActiveJob::TestHelper

  describe "GET index" do
    let(:user) { create(:user) }

    context "without a user_id" do
      it "succeeds when logged out" do
        get :index
        expect(response.status).to eq(200)
      end

      it "succeeds when logged in" do
        login
        get :index
        expect(response.status).to eq(200)
      end

      it "sets correct variables" do
        boards = create_list(:board, 2, creator: user)

        get :index
        expect(assigns(:boards)).to match_array(boards)
        expect(assigns(:page_title)).to eq('Continuities')
      end
    end

    context "with a user_id" do
      it "does not require login" do
        get :index, params: { user_id: user.id }
        expect(response.status).to eq(200)
        expect(assigns(:user)).to eq(user)
        expect(assigns(:page_title)).to eq("#{user.username}'s Continuities")
      end

      it "displays error if user id invalid and logged out" do
        get :index, params: { user_id: -1 }
        expect(flash[:error]).to eq('User could not be found.')
        expect(response).to redirect_to(root_url)
      end

      it "displays error if user id invalid and logged in" do
        login
        get :index, params: { user_id: -1 }
        expect(flash[:error]).to eq('User could not be found.')
        expect(response).to redirect_to(root_url)
      end

      it "does not use logged in user's username" do
        board = create(:board)
        login_as(board.creator)
        get :index, params: { user_id: board.creator_id }
        expect(assigns(:page_title)).to eq('Your Continuities')
      end

      it "sets correct variables" do
        owned_board = create(:board, creator: user)

        get :index, params: { user_id: user.id }
        expect(assigns(:boards)).to match_array([owned_board])

        coauthor = create(:user)
        owned_board2 = create(:board, creator: user, writers: [coauthor])
        owned_board3 = create(:board, creator: user, cameos: [coauthor])

        get :index, params: { user_id: coauthor.id }
        expect(assigns(:boards)).to match_array([owned_board2])
        expect(assigns(:cameo_boards)).to match_array([owned_board3])
      end

      it "orders boards correctly" do
        owned_board1 = create(:board, creator: user, name: 'da')
        owned_board2 = create(:board, creator: user, name: 'ba')
        author_board1 = create(:board, writers: [user], name: 'aa')
        author_board2 = create(:board, writers: [user], name: 'ca')
        cameo_board1 = create(:board, cameos: [user], name: 'bb')
        cameo_board2 = create(:board, cameos: [user], name: 'ab')
        cameo_board3 = create(:board, cameos: [user], name: 'cb')

        get :index, params: { user_id: user.id }
        expect(assigns(:boards)).to eq([author_board1, owned_board2, author_board2, owned_board1])
        expect(assigns(:cameo_boards)).to eq([cameo_board2, cameo_board1, cameo_board3])
      end
    end
  end

  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds when logged in" do
      login
      get :new
      expect(response.status).to eq(200)
    end

    it "sets correct variables" do
      user = create(:user)
      login_as(user)
      other_users = create_list(:user, 3)

      get :new

      expect(assigns(:board)).to be_an_instance_of(Board)
      expect(assigns(:board)).to be_a_new_record
      expect(assigns(:board).creator_id).to eq(user.id)
      expect(assigns(:page_title)).to eq("New Continuity")

      expect(assigns(:coauthors).size).to eq(3)
      expect(assigns(:coauthors)).to match_array(other_users)
      expect(assigns(:coauthors)).not_to include(user)
      expect(assigns(:coauthors).sort_by(&:username)).to eq(assigns(:coauthors))

      expect(assigns(:cameos).size).to eq(3)
      expect(assigns(:cameos)).to match_array(other_users)
      expect(assigns(:cameos)).not_to include(user)
      expect(assigns(:cameos).sort_by(&:username)).to eq(assigns(:cameos))
    end
  end

  describe "POST create" do
    let(:user) { create(:user) }

    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid params" do
      login
      post :create
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Continuity could not be created.")
      expect(flash[:error][:array]).to be_present
      expect(response).to render_template('new')
    end

    it "sets correct variables on failure" do
      login_as(user)
      other_users = create_list(:user, 3)

      post :create

      expect(assigns(:board)).to be_an_instance_of(Board)
      expect(assigns(:board)).to be_a_new_record
      expect(assigns(:board)).not_to be_valid
      expect(assigns(:board).creator).to eq(user)
      expect(assigns(:page_title)).to eq("New Continuity")

      expect(assigns(:coauthors).size).to eq(3)
      expect(assigns(:coauthors)).to match_array(other_users)
      expect(assigns(:coauthors)).not_to include(user)
      expect(assigns(:coauthors).sort_by(&:username)).to eq(assigns(:coauthors))

      expect(assigns(:cameos).size).to eq(3)
      expect(assigns(:cameos)).to match_array(other_users)
      expect(assigns(:cameos)).not_to include(user)
      expect(assigns(:cameos).sort_by(&:username)).to eq(assigns(:cameos))
    end

    it "successfully makes a board" do
      expect(Board.count).to eq(0)
      login_as(user)
      user2 = create(:user)
      user3 = create(:user)

      post :create, params: {
        board: {
          name: 'TestCreateBoard',
          description: 'Test description',
          coauthor_ids: [user2.id],
          cameo_ids: [user3.id]
        }
      }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:success]).to eq("Continuity created!")
      expect(Board.count).to eq(1)

      board = Board.first
      expect(board.name).to eq('TestCreateBoard')
      expect(board.creator).to eq(user)
      expect(board.description).to eq('Test description')
      expect(board.writers).to match_array([user, user2])
      expect(board.cameos).to match_array([user3])
    end
  end

  describe "GET show" do
    let(:board) { create(:board) }

    it "requires valid board" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Continuity could not be found.")
    end

    it "succeeds with valid board" do
      get :show, params: { id: board.id }
      expect(response.status).to eq(200)
    end

    it "succeeds for logged in users with valid board" do
      login
      get :show, params: { id: board.id }
      expect(response.status).to eq(200)
    end

    it "only fetches the board's first 25 posts" do
      create_list(:post, 26, board: board)
      get :show, params: { id: board.id }
      expect(assigns(:posts).size).to eq(25)
    end

    it "orders the posts by tagged_at in unordered boards" do
      Array.new(3) { create(:post, board: board, tagged_at: Time.zone.now + rand(5..30).hours) }
      get :show, params: { id: board.id }
      expect(assigns(:posts)).to eq(assigns(:posts).sort_by(&:tagged_at).reverse)
    end

    it "orders the posts correctly in ordered boards" do
      section2 = create(:board_section, board: board)
      section1 = create(:board_section, board: board)
      section1.update!(section_order: 0)
      section2.update!(section_order: 1)
      post1, post2, post3 = create_list(:post, 3, board: board, section: section1)
      post4, post5, post6 = create_list(:post, 3, board: board, section: section2)
      post7, post8, post9 = create_list(:post, 3, board: board)
      board.posts.each do |post|
        # skip callbacks so we truly override tagged_at
        post.update_columns(tagged_at: Time.zone.now + rand(5..30).hours) # rubocop:disable Rails/SkipsModelValidations
      end
      post1.update!(section_order: 0)
      post2.update!(section_order: 1)
      post3.update!(section_order: 2)
      post4.update!(section_order: 0)
      post5.update!(section_order: 1)
      post6.update!(section_order: 2)
      post7.update!(section_order: 0)
      post8.update!(section_order: 1)
      post9.update!(section_order: 2)
      get :show, params: { id: board.id }
      # we only order board section posts in the HAML, so manually order them here
      expect(assigns(:board_sections).map(&:posts).map(&:ordered_in_section).map(&:to_a)).to eq([[post1, post2, post3], [post4, post5, post6]])
      expect(assigns(:posts)).to eq([post7, post8, post9])
    end

    it "calculates OpenGraph meta" do
      user = create(:user, username: 'John Doe')
      board = create(:board, name: 'board', creator: user, writers: [create(:user, username: 'Jane Doe')], description: 'sample board')
      create(:post, subject: 'title', user: user, board: board)
      get :show, params: { id: board.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(continuity_url(board))
      expect(meta_og[:title]).to eq('board')
      expect(meta_og[:description]).to eq("Jane Doe, John Doe – 1 post\nsample board")
    end
  end

  describe "GET edit" do
    let(:board) { create(:board) }

    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid board" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Continuity could not be found.")
    end

    it "requires board permission" do
      login
      get :edit, params: { id: board.id }
      expect(response).to redirect_to(continuity_url(board))
      expect(flash[:error]).to eq("You do not have permission to edit that continuity.")
    end

    it "succeeds with valid board" do
      login_as(board.creator)
      get :edit, params: { id: board.id }
      expect(response.status).to eq(200)
    end

    it "sets expected variables" do
      coauthor = create(:user)
      board = create(:board, writers: [coauthor])
      sections = [create(:board_section, board: board), create(:board_section, board: board)]
      posts = [create(:post, board: board, user: board.creator, tagged_at: Time.zone.now + 5.minutes), create(:post, user: coauthor, board: board)]
      sections[0].update!(section_order: 1)
      sections[1].update!(section_order: 0)
      login_as(board.creator)
      get :edit, params: { id: board.id }
      expect(assigns(:board_sections)).to eq(sections.reverse)
      expect(assigns(:unsectioned_posts)).to eq(posts)
    end
  end

  describe "PUT update" do
    let(:user) { create(:user) }
    let(:board) { create(:board, creator: user) }

    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid board" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Continuity could not be found.")
    end

    it "requires board permission" do
      login
      put :update, params: { id: board.id }
      expect(response).to redirect_to(continuity_url(board))
      expect(flash[:error]).to eq("You do not have permission to edit that continuity.")
    end

    it "requires valid params" do
      login_as(user)
      put :update, params: { id: board.id, board: {name: ''} }
      expect(response).to render_template('edit')
      expect(flash[:error][:message]).to eq("Continuity could not be created.")
      expect(flash[:error][:array]).to be_present
    end

    it "succeeds" do
      name = board.name
      login_as(user)
      user2 = create(:user)
      user3 = create(:user)
      put :update, params: {
        id: board.id,
        board: {
          name: name + 'edit',
          description: 'New description',
          coauthor_ids: [user2.id],
          cameo_ids: [user3.id]
        }
      }
      expect(response).to redirect_to(continuity_url(board))
      expect(flash[:success]).to eq("Continuity saved!")
      board.reload
      expect(board.name).to eq(name + 'edit')
      expect(board.description).to eq('New description')
      expect(board.writers).to match_array([user, user2])
      expect(board.cameos).to match_array([user3])
    end
  end

  describe "DELETE destroy" do
    let(:user) { create(:user) }
    let(:board) { create(:board, creator: user) }

    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid board" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Continuity could not be found.")
    end

    it "requires board permission" do
      login
      delete :destroy, params: { id: board.id }
      expect(response).to redirect_to(continuity_url(board))
      expect(flash[:error]).to eq("You do not have permission to edit that continuity.")
    end

    it "succeeds" do
      login_as(user)
      delete :destroy, params: { id: board.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:success]).to eq("Continuity deleted.")
    end

    it "moves posts to sandboxes" do
      create(:board, id: Board::ID_SANDBOX)
      section = create(:board_section, board: board)
      post = create(:post, board: board, section: section)
      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        delete :destroy, params: { id: board.id }
      end
      expect(response).to redirect_to(continuities_url)
      expect(flash[:success]).to eq('Continuity deleted.')
      post.reload
      expect(post.board_id).to eq(Board::ID_SANDBOX)
      expect(post.section).to be_nil
      expect(BoardSection.find_by_id(section.id)).to be_nil
    end

    it "handles destroy failure" do
      post = create(:post, user: user, board: board)
      login_as(user)
      expect_any_instance_of(Board).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: board.id }
      expect(response).to redirect_to(continuity_url(board))
      expect(flash[:error]).to eq({message: "Continuity could not be deleted.", array: []})
      expect(post.reload.board).to eq(board)
    end
  end

  describe "POST mark" do
    it "requires login" do
      post :mark
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires board id" do
      login
      post :mark
      expect(response).to redirect_to(unread_posts_url)
      expect(flash[:error]).to eq("Continuity could not be found.")
    end

    it "requires valid board id" do
      login
      post :mark, params: { board_id: -1 }
      expect(response).to redirect_to(unread_posts_url)
      expect(flash[:error]).to eq("Continuity could not be found.")
    end

    it "requires valid action" do
      login
      post :mark, params: { board_id: create(:board).id }
      expect(response).to redirect_to(unread_posts_url)
      expect(flash[:error]).to eq("Please choose a valid action.")
    end

    context "successfully" do
      let(:board) { create(:board) }
      let(:user) { create(:user) }
      let(:now) { Time.zone.now }

      before(:each) { login_as(user) }

      it "marks board read" do
        now
        expect(board.last_read(user)).to be_nil
        post :mark, params: { board_id: board.id, commit: "Mark Read" }
        expect(board.reload.last_read(user)).to be >= now # reload to reset cached @view
        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("#{board.name} marked as read.")
      end

      it "marks extant post views read" do
        read_post = create(:post, user: user, board: board)
        read_post.mark_read(user, at_time: now - 1.day, force: true)
        unread_post = create(:post, user: user, board: board)
        unread_post.mark_read(create(:user), at_time: now - 1.day, force: true)

        expect(board.reload.last_read(user)).to be_nil
        expect(read_post.reload.last_read(user)).to be_the_same_time_as(now - 1.day)
        expect(unread_post.reload.last_read(user)).to be_nil

        post :mark, params: { board_id: board.id, commit: "Mark Read" }

        expect(board.reload.last_read(user)).to be >= now
        expect(read_post.reload.last_read(user)).to be >= now
        expect(unread_post.reload.last_read(user)).to be_nil
      end

      it "ignores board" do
        expect(board).not_to be_ignored_by(user)
        post :mark, params: { board_id: board.id, commit: "Hide from Unread" }
        expect(board.reload).to be_ignored_by(user)
        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("#{board.name} hidden from this page.")
      end
    end
  end

  describe "GET search" do
    context "no search" do
      it "works logged out" do
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Continuities')
        expect(assigns(:search_results)).to be_nil
      end

      it "works logged in" do
        login
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Continuities')
        expect(assigns(:search_results)).to be_nil
      end
    end

    context "searching" do
      it "finds all when no arguments given" do
        create_list(:board, 4)
        get :search, params: { commit: true }
        expect(assigns(:search_results)).to match_array(Board.all)
      end

      it "filters by name" do
        board1 = create(:board, name: 'contains stars')
        board2 = create(:board, name: 'contains Stars cased')
        create(:board, name: 'unrelated')
        get :search, params: { commit: true, name: 'stars' }
        expect(assigns(:search_results)).to match_array([board1, board2])
      end

      it "filters by authors" do
        user = create(:user)
        board1 = create(:board, creator: user)
        create_list(:board, 2)
        board4 = create(:board, coauthors: [user])
        get :search, params: { commit: true, author_id: [user.id] }
        expect(assigns(:search_results)).to match_array([board1, board4])
      end

      it "filters by multiple authors" do
        author1 = create(:user)
        author2 = create(:user)

        create(:board, creator: author1) # one author but not the other
        create(:board, coauthors: [author2]) # one author but not the other, coauthor

        boards = [create(:board, creator: author1, coauthors: [author2])] # both authors
        boards << create(:board, coauthors: [author1, author2]) # both authors coauthors
        boards << create(:board, coauthors: [author1], cameos: [author2]) # both authors, one cameo

        get :search, params: { commit: true, author_id: [author1.id, author2.id] }
        expect(assigns(:search_results)).to match_array(boards)
      end

      it "orders boards by name" do
        ['baa', 'aab', 'aba'].each { |name| create(:board, name: name) }
        get :search, params: { commit: 'Search', name: 'b' }
        expect(assigns(:search_results).map(&:name)).to eq(['aab', 'aba', 'baa'])
      end
    end
  end

  describe "#editor_setup" do
    it "gets the correct set of available cowriters" do
      login
      users = create_list(:user, 3)
      controller.send(:editor_setup)
      expect(assigns(:cameos)).to match_array(users)
      expect(assigns(:coauthors)).to match_array(users)
    end

    it "gets the correct set of available cowriters on an existing board" do
      users = create_list(:user, 3)
      coauthors = [create(:user)]
      cameos = [create(:user), create(:user)]
      board = create(:board, writers: coauthors, cameos: cameos)
      login_as(board.creator)
      board.reload
      controller.instance_variable_set(:@board, board)
      controller.send(:editor_setup)
      expect(assigns(:cameos)).to match_array(users + cameos)
      expect(assigns(:coauthors)).to match_array(users + coauthors)
    end

    it "orders them correctly" do
      login
      user2 = create(:user, username: 'user2')
      user1 = create(:user, username: 'user1')
      user3 = create(:user, username: 'user3')
      controller.send(:editor_setup)
      expect(assigns(:cameos)).to eq([user1, user2, user3])
      expect(assigns(:coauthors)).to eq([user1, user2, user3])
    end
  end
end
