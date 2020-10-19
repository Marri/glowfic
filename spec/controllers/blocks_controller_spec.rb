RSpec.describe BlocksController, type: :controller do
  describe "GET index" do
    it "requires login" do
      get :index
      expect(response).to redirect_to(root_url)
    end

    it "succeeds" do
      login
      get :index
      expect(response.status).to eq(200)
    end

    it "succeeds with existing blocks" do
      user = create(:user)
      create_list(:block, 2, blocking_user: user)
      login_as(user)
      get :index
      expect(response.status).to eq(200)
    end
  end

  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
    end

    it "succeeds" do
      login
      get :new
      expect(response.status).to eq(200)
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
    end

    it "requires a blocked user" do
      login
      post :create
      expect(response).to render_template('new')
      expect(flash[:error][:message]).to eq("User could not be blocked because of the following problems:")
      expect(flash[:error][:array]).to include("Blocked user must exist")
    end

    it "requires valid variables" do
      login
      expect {
        post :create, params: { block: { blocked_user_id: create(:user).id, hide_me: -1 } }
      }.to raise_error(ArgumentError)
    end

    it "requires an existing user to block" do
      login
      post :create, params: { block: { blocked_user_id: ([1] + User.order(id: :desc).limit(1).pluck(:id)).max + 1 } }
      expect(response).to render_template('new')
      expect(flash[:error][:message]).to eq("User could not be blocked because of the following problems:")
      expect(flash[:error][:array]).to include("Blocked user must exist")
      expect(assigns[:block].blocked_user).to be_nil
    end

    it "does not let the user block themself" do
      user = create(:user)
      login_as(user)
      post :create, params: { block: { blocked_user_id: user.id } }
      expect(response).to render_template('new')
      expect(flash[:error][:message]).to eq("User could not be blocked because of the following problems:")
      expect(flash[:error][:array]).to include("User cannot block themself")
    end

    it "succeeds" do
      blocker = create(:user)
      blockee = create(:user)
      login_as(blocker)
      expect {
        post :create, params: {
          block: {
            blocked_user_id: blockee.id,
            block_interactions: false,
            hide_them: :posts,
            hide_me: :all
          }
        }
      }.to change { Block.count }.by(1)
      expect(response).to redirect_to(blocks_url)
      expect(flash[:success]).to eq("User blocked.")
      block = assigns(:block)
      expect(block).not_to be_nil
      expect(block.blocking_user).to eq(blocker)
      expect(block.blocked_user).to eq(blockee)
      expect(block.block_interactions).to eq(false)
      expect(block).to be_hide_them_posts
      expect(block).to be_hide_me_all
    end

    it "refreshes caches" do
      user = create(:user)
      blocked = create(:user)
      blocking = create(:user)
      create(:block, blocking_user: blocking, blocked_user: user, hide_me: :posts)
      blocked_post = create(:post, user: blocking, authors_locked: true)
      hidden_post = create(:post, user: blocked, authors_locked: true)
      user_post = create(:post, user: user, authors_locked: true)

      memory_store = ActiveSupport::Cache.lookup_store(:memory_store)
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      expect(user.hidden_posts).to be_empty
      expect(user.blocked_posts).to eq([blocked_post.id])
      expect(blocked.blocked_posts).to be_empty

      login_as(user)

      post :create, params: {
        block: {
          blocked_user_id: blocked.id,
          block_interactions: false,
          hide_them: :posts,
          hide_me: :posts
        }
      }

      expect(Rails.cache.exist?(Block.cache_string_for(user.id, 'blocked'))).to be(true)
      expect(Rails.cache.exist?(Block.cache_string_for(user.id, 'hidden'))).to be(false)
      expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

      expect(user.hidden_posts).to eq([hidden_post.id])
      expect(blocked.blocked_posts).to eq([user_post.id])
    end
  end

  describe "GET edit" do
    it "requires permission" do
      block = create(:block)
      login
      get :edit, params: { id: block.id }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("Block could not be found.")
    end

    it "requires valid block" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("Block could not be found.")
    end

    it "succeeds" do
      block = create(:block)
      login_as(block.blocking_user)
      get :edit, params: { id: block.id }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT update" do
    it "requires permission" do
      block = create(:block)
      login
      put :update, params: { id: block.id }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("Block could not be found.")
    end

    it "requires valid block" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("Block could not be found.")
    end

    it "requires valid variables" do
      block = create(:block)
      login_as(block.blocking_user)
      expect {
        put :update, params: { id: block.id, block: { hide_them: -1 } }
      }.to raise_error(ArgumentError)
    end

    it "suceeds" do
      block = create(:block)
      login_as(block.blocking_user)
      put :update, params: {
        id: block.id,
        block: {
          block_interactions: false,
          hide_them: :posts,
          hide_me: :all
        }
      }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:success]).to eq("Block updated.")
      new_block = block.reload
      expect(new_block).not_to be_nil
      expect(new_block.blocking_user).to eq(block.blocking_user)
      expect(new_block.blocked_user).to eq(block.blocked_user)
      expect(new_block.block_interactions).to eq(false)
      expect(new_block).to be_hide_them_posts
      expect(new_block).to be_hide_me_all
    end

    it "does not update blocked_user" do
      block = create(:block)
      blocked_user = block.blocked_user
      login_as(block.blocking_user)
      put :update, params: { id: block.id, block: { blocked_user: create(:user).id } }
      expect(response).to redirect_to(blocks_url)
      expect(assigns(:block).blocked_user).to eq(blocked_user)
    end
  end

  describe "DELETE destroy" do
    it "requires permission" do
      block = create(:block)
      login
      delete :destroy, params: { id: block.id }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("Block could not be found.")
    end

    it "requires valid block" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("Block could not be found.")
    end

    it "handles failure" do
      block = create(:block)
      login_as(block.blocking_user)
      expect_any_instance_of(Block).to receive(:destroy).and_return(false)
      delete :destroy, params: {id: block.id}
      expect(response).to redirect_to(blocks_url)
      expect(flash[:error]).to eq("User could not be unblocked.")
      expect(Block.find_by(id: block.id)).to eq(block)
    end

    it "succeeds" do
      block = create(:block)
      login_as(block.blocking_user)
      delete :destroy, params: { id: block.id }
      expect(response).to redirect_to(blocks_url)
      expect(flash[:success]).to eq("User unblocked.")
      expect(Block.find_by(id: block.id)).to be_nil
    end

    it "refreshes caches" do
      user = create(:user)
      blocked = create(:user)
      blocking = create(:user)
      block = create(:block, blocking_user: user, blocked_user: blocked, hide_me: :posts, hide_them: :posts)
      create(:block, blocking_user: blocking, blocked_user: user, hide_me: :posts)
      blocked_post = create(:post, user: blocking, authors_locked: true)
      hidden_post = create(:post, user: blocked, authors_locked: true)
      user_post = create(:post, user: user, authors_locked: true)

      memory_store = ActiveSupport::Cache.lookup_store(:memory_store)
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      expect(user.hidden_posts).to eq([hidden_post.id])
      expect(user.blocked_posts).to eq([blocked_post.id])
      expect(blocked.blocked_posts).to eq([user_post.id])

      login_as(user)

      delete :destroy, params: { id: block.id }

      expect(Rails.cache.exist?(Block.cache_string_for(user.id, 'blocked'))).to be(true)
      expect(Rails.cache.exist?(Block.cache_string_for(user.id, 'hidden'))).to be(false)
      expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

      expect(user.hidden_posts).to be_empty
      expect(blocked.blocked_posts).to be_empty
    end
  end
end
