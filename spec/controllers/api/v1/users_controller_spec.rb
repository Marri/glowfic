RSpec.describe Api::V1::UsersController do
  describe "GET index" do
    def create_search_users
      names = ['baa', 'aba', 'aab', 'aaa']
      names.each {|name| create(:user, username: name) }
      names.each {|name| create(:user, username: name.upcase + 'c') }
    end

    it "works logged in" do
      create_search_users
      api_login
      get :index
      expect(response).to have_http_status(200)
      expect(response.json['results'].count).to eq(9)
    end

    it "works logged out", show_in_doc: true do
      create_search_users
      get :index, params: { q: 'b' }
      expect(response).to have_http_status(200)
      expect(response.json['results'].count).to eq(2)
    end

    it "raises error on invalid page", show_in_doc: true do
      get :index, params: { page: 'b' }
      expect(response).to have_http_status(422)
    end

    it "supports exact match", show_in_doc: true do
      create(:user, username: 'alicorn')
      create(:user, username: 'ali')
      get :index, params: { q: 'ali', match: 'exact' }
      expect(response.json['results'].count).to eq(1)
    end

    context "with blocks" do
      before(:each) do
        user = create(:user)
        api_login_as(user)
        create_list(:block, 2, blocking_user: user)
        create_list(:user, 3)
      end

      it "handles hiding unblockable users" do
        get :index, params: { hide_unblockable: true }
        expect(response.json['results'].count).to eq(3)
      end

      it "does not hide unblockable users unless that parameter is sent" do
        get :index
        expect(response.json['results'].count).to eq(6)
      end
    end

    it "does not return deleted users" do
      create(:user, deleted: true)
      create(:user)
      get :index
      expect(response.json['results'].count).to eq(1)
    end

    it "shows moieties appropriately" do
      create(:user, username: 'Throne3d', moiety: '960018', moiety_name: 'Carmine')
      create(:user, username: 'anon')
      get :index
      expect(response.json['results']).to contain_exactly(
        a_collection_including(
          'username'    => 'Throne3d',
          'moiety'      => '960018',
          'moiety_name' => 'Carmine',
        ),
        a_collection_including(
          'username'    => 'anon',
          'moiety'      => nil,
          'moiety_name' => nil,
        ),
      )
    end
  end

  describe 'GET posts' do
    let(:user) { create(:user) }

    it 'requires a valid user', show_in_doc: true do
      get :posts, params: { id: 0 }
      expect(response).to have_http_status(404)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("User could not be found.")
    end

    it 'filters non-public posts' do
      public_post = create(:post, privacy: :public, user: user)
      create(:post, privacy: :private, user: user)
      get :posts, params: { id: user.id }
      expect(response).to have_http_status(200)
      expect(response.json['results'].size).to eq(1)
      expect(response.json['results'][0]['id']).to eq(public_post.id)
    end

    it 'returns only the correct posts', show_in_doc: true do
      board = create(:board)
      user_post = create(:post, user: user, board: board, section: create(:board_section, board: board))
      create(:post, user: create(:user))
      get :posts, params: { id: user.id }
      expect(response).to have_http_status(200)
      expect(response.json['results'].size).to eq(1)
      expect(response.json['results'][0]['id']).to eq(user_post.id)
      expect(response.json['results'][0]['board']['id']).to eq(user_post.board_id)
      expect(response.json['results'][0]['section']['id']).to eq(user_post.section_id)
    end

    it 'paginates results' do
      create_list(:post, 26, user: user)
      get :posts, params: { id: user.id }
      expect(response.json['results'].size).to eq(25)
    end

    it 'paginates results on additional pages' do
      create_list(:post, 27, user: user)
      get :posts, params: { id: user.id, page: 2 }
      expect(response.json['results'].size).to eq(2)
    end
  end
end
