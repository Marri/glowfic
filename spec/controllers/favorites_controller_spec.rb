RSpec.describe FavoritesController do
  describe "GET index" do
    it "succeeds when logged out" do
      get :index
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds when logged in" do
      login
      get :index
      expect(response.status).to eq(200)
    end

    it "has no posts when no favorites" do
      login
      get :index
      expect(assigns(:posts)).to be_empty
    end

    context "it only shows favorites" do
      let (:user) { create(:user) }
      let (:user_post) { create(:post, user: user) }
      let (:post) { create(:post) }
      let (:board) { create(:board, creator: user) }
      let (:board_post) { create(:post, board: board) }
      let (:board_user_post) { create(:post, board: board, user: user) }

      before(:each) do
        user_post
        post
        board_post
        board_user_post
      end

      it "shows user's post when user is favorited" do
        favorite = create(:favorite, favorite: user)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([user_post, board_user_post])
      end

      it "shows post when post is favorited" do
        favorite = create(:favorite, favorite: post)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([post])
      end

      it "shows board posts when board is favorited" do
        favorite = create(:favorite, favorite: board)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([board_post, board_user_post])
      end

      it "shows both post and user post when post and user are favorited" do
        favorite = create(:favorite, favorite: post)
        favorite = create(:favorite, user: favorite.user, favorite: user)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([post, user_post, board_user_post])
      end

      it "shows both post and board post when post and board are favorited" do
        favorite = create(:favorite, favorite: post)
        favorite = create(:favorite, user: favorite.user, favorite: board)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([post, board_post, board_user_post])
      end

      it "shows user and board posts when board and user are favorited" do
        favorite = create(:favorite, favorite: user)
        favorite = create(:favorite, user: favorite.user, favorite: board)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([user_post, board_post, board_user_post])
      end

      it "does not duplicate posts if both a user post and user are favorited" do
        favorite = create(:favorite, favorite: user_post)
        favorite = create(:favorite, user: favorite.user, favorite: user)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([user_post, board_user_post])
      end

      it "does not duplicate posts if both a board post and board are favorited" do
        favorite = create(:favorite, favorite: board_post)
        favorite = create(:favorite, user: favorite.user, favorite: board)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([board_post, board_user_post])
      end

      it "handles all three types simultaneously" do
        favorite = create(:favorite, favorite: post)
        favorite = create(:favorite, user: favorite.user, favorite: board)
        favorite = create(:favorite, user: favorite.user, favorite: user)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to match_array([board_post, board_user_post, user_post, post])
      end

      it "orders favorited posts correctly" do
        user_post.update!(tagged_at: Time.zone.now - 2.minutes)
        board_post.update!(tagged_at: Time.zone.now - 5.minutes)
        board_user_post.update!(tagged_at: Time.zone.now)
        favorite = create(:favorite, favorite: board)
        create(:favorite, user: favorite.user, favorite: user)
        login_as(favorite.user)
        get :index
        expect(assigns(:posts)).to eq([board_user_post, user_post, board_post])
      end
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires a valid param" do
      login
      post :create
      expect(response).to redirect_to(continuities_path)
      expect(flash[:error]).to eq('No favorite specified.')
    end

    it "requires valid user if given" do
      login
      post :create, params: { user_id: -1 }
      expect(response).to redirect_to(users_path)
      expect(flash[:error]).to eq('User could not be found.')
    end

    it "requires valid post if given" do
      login
      post :create, params: { post_id: -1 }
      expect(response).to redirect_to(posts_path)
      expect(flash[:error]).to eq('Post could not be found.')
    end

    it "requires valid board if given" do
      login
      post :create, params: { board_id: -1 }
      expect(response).to redirect_to(continuities_path)
      expect(flash[:error]).to eq('Continuity could not be found.')
    end

    it "handles invalid favorite" do
      user = create(:user)
      login_as(user)
      post :create, params: { user_id: user.id }
      expect(response).to redirect_to(user_path(user))
      expect(flash[:error][:message]).to eq('Favorite could not be saved because of the following problems:')
    end

    it "favorites a user" do
      user = create(:user)
      fav = create(:user)
      login_as(user)
      post :create, params: { user_id: fav.id }
      expect(Favorite.between(user, fav)).not_to be_nil
      expect(response).to redirect_to(user_url(fav))
      expect(flash[:success]).to eq("Your favorite has been saved.")
    end

    it "favorites a post" do
      user = create(:user)
      fav = create(:post)
      login_as(user)
      post :create, params: { post_id: fav.id }
      expect(Favorite.between(user, fav)).not_to be_nil
      expect(response).to redirect_to(post_url(fav))
      expect(flash[:success]).to eq("Your favorite has been saved.")
    end

    it "favorites a post with a page/per redirect" do
      user = create(:user)
      fav = create(:post)
      login_as(user)
      post :create, params: { post_id: fav.id, page: 3, per_page: 10 }
      expect(Favorite.between(user, fav)).not_to be_nil
      expect(response).to redirect_to(post_url(fav, page: 3, per_page: 10))
      expect(flash[:success]).to eq("Your favorite has been saved.")
    end

    it "favorites a post without a page redirect for first page" do
      user = create(:user)
      fav = create(:post)
      login_as(user)
      post :create, params: { post_id: fav.id, page: 1, per_page: 25 }
      expect(Favorite.between(user, fav)).not_to be_nil
      expect(response).to redirect_to(post_url(fav))
      expect(flash[:success]).to eq("Your favorite has been saved.")
    end

    it "favorites a board" do
      user = create(:user)
      board = create(:board)
      login_as(user)
      post :create, params: { board_id: board.id }
      expect(Favorite.between(user, board)).not_to be_nil
      expect(response).to redirect_to(continuity_url(board))
      expect(flash[:success]).to eq("Your favorite has been saved.")
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid favorite" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(favorites_url)
      expect(flash[:error]).to eq("Favorite could not be found.")
    end

    it "requires your favorite" do
      login
      delete :destroy, params: { id: create(:favorite, favorite: create(:user)).id }
      expect(response).to redirect_to(favorites_url)
      expect(flash[:error]).to eq("That is not your favorite.")
    end

    it "destroys board favorite" do
      favorite = create(:favorite, favorite: create(:board))
      login_as(favorite.user)
      delete :destroy, params: { id: favorite.id }
      expect(response).to redirect_to(continuity_url(favorite.favorite))
      expect(flash[:success]).to eq("Favorite removed.")
    end

    it "destroys post favorite" do
      favorite = create(:favorite, favorite: create(:post))
      login_as(favorite.user)
      delete :destroy, params: { id: favorite.id }
      expect(response).to redirect_to(post_url(favorite.favorite))
      expect(flash[:success]).to eq("Favorite removed.")
    end

    it "destroys user favorite" do
      favorite = create(:favorite, favorite: create(:user))
      login_as(favorite.user)
      delete :destroy, params: { id: favorite.id }
      expect(response).to redirect_to(user_url(favorite.favorite))
      expect(flash[:success]).to eq("Favorite removed.")
    end

    it "handles destroy failure" do
      favorite = create(:favorite, favorite: create(:post))
      login_as(favorite.user)
      expect_any_instance_of(Favorite).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: favorite.id }
      expect(response).to redirect_to(favorites_path)
      expect(flash[:error]).to eq("Favorite could not be deleted.")
      expect(Favorite.find_by(id: favorite.id)).not_to be_nil
    end
  end
end
