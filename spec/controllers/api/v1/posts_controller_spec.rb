RSpec.describe Api::V1::PostsController do
  describe "GET index" do
    shared_examples_for "index.json" do |in_doc|
      let!(:post) { create(:post, subject: 'search') }

      it "should support no search", show_in_doc: in_doc do
        get :index
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(post.as_json(min: true).stringify_keys)
      end

      it "should support search", show_in_doc: in_doc do
        create(:post, subject: 'no')
        get :index, params: { q: 'se' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(post.as_json(min: true).stringify_keys)
      end

      it "hides private posts" do
        create(:post, privacy: :private)
        get :index
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(post.as_json(min: true).stringify_keys)
      end
    end

    context "when logged in" do
      before(:each) { api_login }

      it_behaves_like "index.json", false
    end

    context "when logged out" do
      it_behaves_like "index.json", true
    end
  end

  describe "GET show" do
    it "requires valid post", :show_in_doc do
      get :show, params: { id: 0 }
      expect(response).to have_http_status(404)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("Post could not be found.")
    end

    it "requires access to post", :show_in_doc do
      post = create(:post, privacy: :private)
      get :show, params: { id: post.id }
      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "succeeds with valid post", :show_in_doc do
      post = create(:post, with_icon: true, with_character: true)
      get :show, params: { id: post.id }
      expect(response).to have_http_status(200)
      expect(response.json['id']).to eq(post.id)
      expect(response.json['num_replies']).to eq(0)
      expect(response.json['authors'].size).to eq(1)
      expect(response.json['authors'][0]['id']).to eq(post.user_id)
      expect(response.json['content']).to eq(post.content)
      expect(response.json['icon']['id']).to eq(post.icon_id)
      expect(response.json['character']['id']).to eq(post.character_id)
    end
  end

  describe "PATCH update" do
    let(:user) { create(:user) }
    let(:post) { create(:post, user: user) }

    it "requires login", :show_in_doc do
      patch :update, params: { id: 0 }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "requires valid post", :show_in_doc do
      api_login
      patch :update, params: { id: 0 }
      expect(response).to have_http_status(404)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("Post could not be found.")
    end

    it "requires access to post", :show_in_doc do
      api_login
      post = create(:post, privacy: :private)
      patch :update, params: { id: post.id }
      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "requires private_note param", :show_in_doc do
      api_login
      patch :update, params: { id: post.id }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Missing parameter private_note")
    end

    it "requires authorship of post" do
      api_login
      patch :update, params: { id: post.id, private_note: "Shiny new note" }
      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "handles failed saves" do
      expect_any_instance_of(Post::Author).to receive(:update).and_return(false)
      api_login_as(user)

      patch :update, params: { id: post.id, private_note: 'Shiny new note' }

      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq('Post could not be updated.')
    end

    it "succeeds with valid post", :show_in_doc do
      api_login_as(user)
      author = post.author_for(user)
      expect(author.private_note).to be_nil

      patch :update, params: { id: post.id, private_note: 'Shiny new note' }

      expect(response).to have_http_status(200)
      expect(response.json['private_note']).to eq("<p>Shiny new note</p>")
      expect(author.reload.private_note).to eq('Shiny new note')
    end
  end

  describe "POST reorder" do
    let(:user) { create(:user) }
    let(:board) { create(:board, creator: user) }
    let(:section) { create(:board_section, board: board) }

    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    context "without section_id" do
      let(:board2) { create(:board, creator: user) }

      it "requires a board you have access to" do
        posts = create_list(:post, 2, board: board)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        post_ids = posts.map(&:id).reverse
        api_login
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(403)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires a single board" do
        posts = create_list(:post, 1, board: board)
        posts += create_list(:post, 2, board: board2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one board')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
      end

      it "requires section_id if posts in section" do
        posts = create_list(:post, 2, board: board, section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the board, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires valid post_ids" do
        posts = create_list(:post, 2, board: board)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: [-1] }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "works for valid changes", :show_in_doc do
        posts = create_list(:post, 4, board: board)
        posts << create(:post, board: board2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0], posts[3], posts[1]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 3, 0, 2, 0])
      end

      it "works when specifying valid subset", :show_in_doc do
        posts = create_list(:post, 4, board: board)
        posts << create(:post, board: board2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => [posts[2], posts[0], posts[1], posts[3]].map(&:id)})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 2, 0, 3, 0])
      end
    end

    context "with section_id" do
      let(:section2) { create(:board_section, board: board) }

      it "requires a board you have access to" do
        posts = create_list(:post, 2, board: board, section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        post_ids = posts.map(&:id).reverse
        api_login
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(403)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires a single section" do
        posts = create_list(:post, 1, board: board, section: section)
        posts += create_list(:post, 2, board: board, section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the board, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
      end

      it "requires valid section id" do
        posts = create_list(:post, 2, board: board, section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: 0 }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the board, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires correct section id" do
        posts = create_list(:post, 1, board: board, section: section)
        posts += create_list(:post, 2, board: board, section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
        post_ids = posts[1..2].reverse.map(&:id)
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the board, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
      end

      it "requires no section_id if posts not in section" do
        posts = create_list(:post, 2, board: board)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the board, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires valid post_ids" do
        posts = create_list(:post, 2, board: board, section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: [-1], section_id: section.id }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "works for valid changes", :show_in_doc do
        posts = create_list(:post, 4, board: board, section: section)
        posts << create(:post, board: board, section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0], posts[3], posts[1]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 3, 0, 2, 0])
      end

      it "works when specifying valid subset", :show_in_doc do
        posts = create_list(:post, 4, board: board, section: section)
        posts << create(:post, board: board, section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => [posts[2], posts[0], posts[1], posts[3]].map(&:id)})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 2, 0, 3, 0])
      end
    end
  end
end
