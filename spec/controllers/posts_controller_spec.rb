require "spec_helper"

RSpec.describe PostsController do
  describe "GET index" do
    it "has a 200 status code" do
      get :index
      expect(response.status).to eq(200)
    end

    it "paginates" do
      26.times do create(:post) end
      get :index
      num_posts_fetched = controller.instance_variable_get('@posts').total_pages
      expect(num_posts_fetched).to eq(2)
    end

    it "only fetches most recent threads" do
      26.times do create(:post) end
      oldest = Post.order('id asc').first
      get :index
      ids_fetched = controller.instance_variable_get('@posts').map(&:id)
      expect(ids_fetched).not_to include(oldest.id)
    end

    it "only fetches most recent threads based on updated_at" do
      26.times do create(:post) end
      oldest = Post.order('id asc').first
      next_oldest = Post.order('id asc').second
      oldest.update_attributes(content: "just to make it update")
      get :index
      ids_fetched = controller.instance_variable_get('@posts').map(&:id)
      expect(ids_fetched).not_to include(next_oldest.id)
    end
  end

  describe "GET search" do
    context "no search" do
      it "works logged out" do
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Browse Posts')
        expect(assigns(:search_results)).to be_nil
      end

      it "works logged in" do
        login
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Browse Posts')
        expect(assigns(:search_results)).to be_nil
      end
    end

    context "searching" do
      it "finds all when no arguments given" do
        4.times do create(:post) end
        get :search, commit: true
        expect(assigns(:search_results)).to match_array(Post.all)
      end

      it "filters by continuity" do
        post = create(:post)
        post2 = create(:post, board: post.board)
        create(:post)
        get :search, commit: true, board_id: post.board_id
        expect(assigns(:search_results)).to match_array([post, post2])
      end

      it "filters by setting" do
        setting = create(:setting)
        post = create(:post)
        post.settings << setting
        create(:post)
        get :search, commit: true, setting_id: setting.id
        expect(assigns(:search_results)).to match_array([post])
      end

      it "filters by subject" do
        post = create(:post, subject: 'contains stars')
        create(:post, subject: 'unrelated')
        get :search, commit: true, subject: 'stars'
        expect(assigns(:search_results)).to match_array([post])
      end

      it "does not mix up subject with content" do
        create(:post, subject: 'unrelated', content: 'contains stars')
        get :search, commit: true, subject: 'stars'
        expect(assigns(:search_results)).to be_empty
      end

      it "restricts to visible posts" do
        create(:post, subject: 'contains stars', privacy: Post::PRIVACY_PRIVATE)
        post = create(:post, subject: 'visible contains stars')
        get :search, commit: true, subject: 'stars'
        expect(assigns(:search_results)).to match_array([post])
      end

      it "filters by exact match subject" do
        skip "TODO not yet implemented"
      end

      it "filters by authors" do
        posts = 4.times.collect do create(:post) end
        filtered_post = posts.last
        first_post = posts.first
        create(:reply, post: first_post, user: filtered_post.user)
        get :search, commit: true, author_id: filtered_post.user_id
        expect(assigns(:search_results)).to match_array([filtered_post, first_post])
      end

      it "filters by characters" do
        create(:reply, with_character: true)
        reply = create(:reply, with_character: true)
        post = create(:post, character: reply.character, user: reply.user)
        get :search, commit: true, character_id: reply.character_id
        expect(assigns(:search_results)).to match_array([reply.post, post])
      end

      it "filters by completed" do
        create(:post)
        post = create(:post, status: Post::STATUS_COMPLETE)
        get :search, commit: true, completed: true
        expect(assigns(:search_results)).to match_array(post)
      end
    end
  end

  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "sets relevant fields" do
      user = create(:user)
      character = create(:character, user: user)
      user.update_attributes(active_character: character)
      user.reload
      login_as(user)

      get :new

      expect(response).to have_http_status(200)
      expect(assigns(:post)).to be_new_record
      expect(assigns(:post).character).to eq(character)
    end

    it "works for importer" do
      login
      get :new, view: :import
      expect(response).to have_http_status(200)
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    context "scrape" do
      it "requires valid user" do
        user = create(:user, id: PostsController::SCRAPE_USERS.max + 1)
        login_as(user)
        post :create, button_import: true
        expect(response).to render_template(:new)
        expect(flash[:error]).to eq("You do not have access to this feature.")
      end

      it "requires url" do
        user = create(:user, id: PostsController::SCRAPE_USERS.first)
        login_as(user)
        post :create, button_import: true
        expect(response).to render_template(:new)
        expect(flash[:error]).to eq("Invalid URL provided.")
      end

      it "requires dreamwidth url" do
        user = create(:user, id: PostsController::SCRAPE_USERS.first)
        login_as(user)
        post :create, button_import: true, dreamwidth_url: 'http://www.google.com'
        expect(response).to render_template(:new)
        expect(flash[:error]).to eq("Invalid URL provided.")
      end

      it "requires dreamwidth.org url" do
        user = create(:user, id: PostsController::SCRAPE_USERS.first)
        login_as(user)
        post :create, button_import: true, dreamwidth_url: 'http://www.dreamwidth.com'
        expect(response).to render_template(:new)
        expect(flash[:error]).to eq("Invalid URL provided.")
      end

      it "requires well formed url" do
        user = create(:user, id: PostsController::SCRAPE_USERS.first)
        login_as(user)
        expect(URI).to receive(:parse).and_raise(URI::InvalidURIError)
        post :create, button_import: true, dreamwidth_url: 'dreamwidth'
        expect(response).to render_template(:new)
        expect(flash[:error]).to eq("Invalid URL provided.")
      end

      it "requires extant usernames" do
        user = create(:user, id: PostsController::SCRAPE_USERS.first)
        login_as(user)
        url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
        file = File.join(Rails.root, 'spec', 'support', 'fixtures', 'scrape_no_replies.html')
        stub_request(:get, url).to_return(status: 200, body: File.new(file))
        post :create, button_import: true, dreamwidth_url: url
        expect(response).to render_template(:new)
        expect(flash[:error][:message]).to start_with("The following usernames were not recognized")
        expect(flash[:error][:array]).to include("wild_pegasus_appeared")
        expect(ScrapePostJob).to have_queue_size_of(0)
      end

      it "scrapes" do
        user = create(:user, id: PostsController::SCRAPE_USERS.first)
        login_as(user)
        url = 'http://www.dreamwidth.org'
        stub_request(:get, url).to_return(status: 200, body: '')
        post :create, button_import: true, dreamwidth_url: url
        expect(response).to redirect_to(posts_url)
        expect(flash[:success]).to eq("Post has begun importing. You will be updated on progress via site message.")
        expect(ScrapePostJob).to have_queue_size_of(1)
      end
    end

    context "preview" do
      it "sets expected variables" do
        user = create(:user)
        login_as(user)
        post :create, button_preview: true, post: {subject: 'test', content: 'orign'}
        expect(response).to render_template(:preview)
        expect(assigns(:written)).to be_an_instance_of(Post)
        expect(assigns(:written)).to be_a_new_record
        expect(assigns(:written).user).to eq(user)
        expect(assigns(:post)).to eq(assigns(:written))
        expect(assigns(:page_title)).to eq('Previewing: test')
        # TODO editor setup
      end

      it "does not crash without arguments" do
        user = create(:user)
        login_as(user)
        post :create, button_preview: true
        expect(response).to render_template(:preview)
        expect(assigns(:written)).to be_an_instance_of(Post)
        expect(assigns(:written)).to be_a_new_record
        expect(assigns(:written).user).to eq(user)
      end
    end

    it "creates new tags" do
      existing_name = create(:label)
      existing_case = create(:label)
      tags = ['atag', 'atag', create(:label).id, '', existing_name.name, existing_case.name.upcase]
      login
      expect {
        post :create, post: {subject: 'a', board_id: create(:board).id, label_ids: tags}
      }.to change{Label.count}.by(1)
      expect(Label.last.name).to eq('atag')
      expect(assigns(:post).labels.count).to eq(4)
    end

    it "creates new settings" do
      existing_name = create(:setting)
      existing_case = create(:setting)
      tags = ['atag', 'atag', create(:setting).id, '', existing_name.name, existing_case.name.upcase]
      login
      expect {
        post :create, post: {subject: 'a', board_id: create(:board).id, setting_ids: tags}
      }.to change{Setting.count}.by(1)
      expect(Setting.last.name).to eq('atag')
      expect(assigns(:post).settings.count).to eq(4)
    end

    it "creates new content warnings" do
      existing_name = create(:content_warning)
      existing_case = create(:content_warning)
      tags = ['atag', 'atag', create(:content_warning).id, '', existing_name.name, existing_case.name.upcase]
      login
      expect {
        post :create, post: {subject: 'a', board_id: create(:board).id, warning_ids: tags}
      }.to change{ContentWarning.count}.by(1)
      expect(ContentWarning.last.name).to eq('atag')
      expect(assigns(:post).content_warnings.count).to eq(4)
    end

    it "handles invalid posts" do
      user = create(:user)
      login_as(user)
      post :create, post: {subject: 'asubjct', content: 'acontnt'}
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Your post could not be saved because of the following problems:")
      expect(assigns(:post)).not_to be_persisted
      expect(assigns(:post).user).to eq(user)
      expect(assigns(:post).subject).to eq('asubjct')
      expect(assigns(:post).content).to eq('acontnt')
      expect(assigns(:page_title)).to eq('New Post')
      # TODO editor_setup
    end

    it "creates a post" do
      user = create(:user)
      login_as(user)
      expect {
        post :create, post: {subject: 'asubjct', content: 'acontnt', board_id: create(:board).id}
      }.to change{Post.count}.by(1)
      expect(response).to redirect_to(post_path(assigns(:post)))
      expect(flash[:success]).to eq("You have successfully posted.")
      expect(assigns(:post)).to be_persisted
      expect(assigns(:post).user).to eq(user)
      expect(assigns(:post).last_user).to eq(user)
      expect(assigns(:post).subject).to eq('asubjct')
      expect(assigns(:post).content).to eq('acontnt')
    end
  end

  describe "GET show" do
    it "does not require login" do
      post = create(:post)
      get :show, id: post.id
      expect(response).to have_http_status(200)
    end

    it "requires permission" do
      post = create(:post, privacy: Post::PRIVACY_PRIVATE)
      get :show, id: post.id
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "works with login" do
      post = create(:post)
      login
      get :show, id: post.id
      expect(response).to have_http_status(200)
    end

    it "marks read multiple times" do
      post = create(:post)
      user = create(:user)
      login_as(user)
      expect(post.last_read(user)).to be_nil
      get :show, id: post.id
      last_read = post.reload.last_read(user)
      expect(last_read).not_to be_nil

      Timecop.freeze(last_read + 1.second) do
        reply = create(:reply, post: post)
        expect(reply.created_at).not_to be_the_same_time_as(last_read)
        get :show, id: post.id
        cur_read = post.reload.last_read(user)
        expect(last_read).not_to be_the_same_time_as(cur_read)
        expect(last_read.to_i).to be < cur_read.to_i
      end
    end

    it "handles invalid pages" do
      post = create(:post)
      get :show, id: post.id, page: 'invalid'
      expect(flash[:error]).to eq('Page not recognized, defaulting to page 1.')
      expect(assigns(:page)).to eq(1)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    it "handles pages outside range" do
      post = create(:post)
      5.times { create(:reply, post: post) }
      get :show, id: post.id, per_page: 1, page: 10
      expect(response).to redirect_to(post_url(post, page: 5, per_page: 1))
    end

    it "handles page=last with replies" do
      post = create(:post)
      5.times { create(:reply, post: post) }
      get :show, id: post.id, per_page: 1, page: 'last'
      expect(assigns(:page)).to eq(5)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    it "handles page=last with no replies" do
      post = create(:post)
      get :show, id: post.id, page: 'last'
      expect(assigns(:page)).to eq(1)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    context "with render_views" do
      render_views

      it "renders HAML with additional attributes" do
        post = create(:post, with_icon: true, with_character: true)
        create(:reply, post: post, with_icon: true, with_character: true)
        get :show, id: post.id
        expect(response.status).to eq(200)
        expect(response.body).to include(post.subject)
        expect(response.body).to include('header-right')
      end

      it "renders HAML for logged in user" do
        post = create(:post)
        create(:reply, post: post)
        character = create(:character)
        login_as(character.user)
        get :show, id: post.id
        expect(response.status).to eq(200)
        expect(response.body).to include('Join Thread')
      end

      it "flat view renders HAML properly" do
        post = create(:post, with_icon: true, with_character: true)
        create(:reply, post: post, with_icon: true, with_character: true)
        get :show, id: post.id, view: 'flat'
        expect(response.status).to eq(200)
        expect(response.body).to include(post.subject)
        expect(response.body).not_to include('header-right')
      end
    end

    context "with at_id" do
      let(:post) { create(:post) }
      before(:each) do
        5.times do create(:reply, post: post) end
      end

      it "shows error if reply not found" do
        get :show, id: post.id, at_id: -1
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "shows error if unread not logged in" do
        get :show, id: post.id, at_id: 'unread'
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "shows error if no unread" do
        user = create(:user)
        post.mark_read(user)
        login_as(user)
        get :show, id: post.id, at_id: 'unread'
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "shows error when reply is wrong post" do
        get :show, id: post.id, at_id: create(:reply).id
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "works for specified reply" do
        last_reply = post.replies.order('id asc').last
        get :show, id: post.id, at_id: last_reply.id
        expect(assigns(:replies)).to eq([last_reply])
        expect(assigns(:replies).current_page.to_i).to eq(1)
        expect(assigns(:replies).per_page).to eq(25)
      end

      it "works for specified reply with page settings" do
        second_last_reply = post.replies.order('id asc').last(2).first
        get :show, id: post.id, at_id: second_last_reply.id, per_page: 1
        expect(assigns(:replies)).to eq([second_last_reply])
        expect(assigns(:replies).current_page.to_i).to eq(1)
        expect(assigns(:replies).per_page).to eq(1)
      end

      it "works for specified reply with page settings" do
        last_reply = post.replies.order('id asc').last
        second_last_reply = post.replies.order('id asc').last(2).first
        get :show, id: post.id, at_id: second_last_reply.id, per_page: 1, page: 2
        expect(assigns(:replies)).to eq([last_reply])
        expect(assigns(:replies).current_page.to_i).to eq(2)
        expect(assigns(:replies).per_page).to eq(1)
      end

      it "works for unread" do
        third_reply = post.replies.order('id asc').limit(3).last
        second_last_reply = post.replies.order('id asc').last(2).first
        user = create(:user)
        post.mark_read(user, third_reply.created_at)
        expect(post.first_unread_for(user)).to eq(second_last_reply)
        login_as(user)
        get :show, id: post.id, at_id: 'unread', per_page: 1
        expect(assigns(:replies)).to eq([second_last_reply])
        expect(assigns(:unread)).to eq(second_last_reply)
        expect(assigns(:paginate_params)['at_id']).to eq(second_last_reply.id)
      end
    end

    context "page=unread" do
      it "goes to the end if you're up to date" do
        post = create(:post)
        3.times do create(:reply, post: post, user: post.user) end
        user = create(:user)
        post.mark_read(user)
        login_as(user)
        get :show, id: post.id, page: 'unread', per_page: 1
        expect(assigns(:page)).to eq(3)
      end

      it "goes to beginning if you've never read it" do
        post = create(:post)
        user = create(:user)
        login_as(user)
        get :show, id: post.id, page: 'unread'
        expect(assigns(:page)).to eq(1)
      end

      it "goes to post page if you're behind" do
        post = create(:post)
        reply1 = create(:reply, post: post, user: post.user)
        reply2 = Timecop.freeze(reply1.created_at + 1.second) do create(:reply, post: post, user: post.user) end
        reply3 = Timecop.freeze(reply1.created_at + 2.seconds) do create(:reply, post: post, user: post.user) end
        user = create(:user)
        post.mark_read(user, reply1.created_at)
        login_as(user)
        get :show, id: post.id, page: 'unread', per_page: 1
        expect(assigns(:page)).to eq(2)
      end
    end

    context "with author" do
      it "works" do
        post = create(:post)
        login_as(post.user)
        get :show, id: post.id
        expect(response).to have_http_status(200)
      end

      it "sets reply variable using build_new_reply_for" do
        post = create(:post, with_icon: true, with_character: true)
        user = post.user
        post.reload

        # mock Post.find_by_id so we can mock post.build_new_reply_for
        allow(Post).to receive(:find_by_id).with(post.id.to_s).and_return(post)

        login_as(user)
        expect(post).to be_taggable_by(user)
        expect(post).to receive(:build_new_reply_for).with(user).and_call_original

        get :show, id: post.id
        expect(response).to have_http_status(200)
        expect(assigns(:reply)).not_to be_nil
      end
    end

    context "with non-author who can write" do
      it "works" do
        post = create(:post, authors_locked: false)
        user = create(:user)
        login_as(user)
        expect(post).to be_taggable_by(user)
        get :show, id: post.id
        expect(response).to have_http_status(200)
      end

      it "sets reply variable using build_new_reply_for" do
        post = create(:post, with_icon: true, with_character: true)
        user = create(:user)
        post.reload

        # mock Post.find_by_id so we can mock post.build_new_reply_for
        allow(Post).to receive(:find_by_id).with(post.id.to_s).and_return(post)

        login_as(user)
        expect(post).to be_taggable_by(user)
        expect(post).to receive(:build_new_reply_for).with(user).and_call_original

        get :show, id: post.id
        expect(response).to have_http_status(200)
        expect(assigns(:reply)).not_to be_nil
      end
    end

    context "with user who cannot write" do
      it "works and does not call build_new_reply_for" do
        post = create(:post, authors_locked: true)
        user = create(:user)
        post.reload

        # mock Post.find_by_id so we can mock post.build_new_reply_for
        allow(Post).to receive(:find_by_id).with(post.id.to_s).and_return(post)

        login_as(user)
        expect(post).not_to be_taggable_by(user)
        expect(post).not_to receive(:build_new_reply_for)

        get :show, id: post.id
        expect(response).to have_http_status(200)
        expect(assigns(:reply)).to be_nil
      end
    end

    # TODO WAY more tests
  end

  describe "GET history" do
    it "requires post" do
      login
      get :history, id: -1
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "works logged out" do
      get :history, id: create(:post).id
      expect(response.status).to eq(200)
    end

    it "works logged in" do
      login
      get :history, id: create(:post).id
      expect(response.status).to eq(200)
    end
  end

  describe "GET stats" do
    it "requires post" do
      login
      get :stats, id: -1
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "works logged out" do
      get :stats, id: create(:post).id
      expect(response.status).to eq(200)
    end

    it "works logged in" do
      login
      get :stats, id: create(:post).id
      expect(response.status).to eq(200)
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, id: -1
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires post" do
      login
      get :edit, id: -1
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires your post" do
      login
      post = create(:post)
      get :edit, id: post.id
      expect(response).to redirect_to(post_url(post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "sets relevant fields" do
      user = create(:user)
      character = create(:character, user: user)
      post = create(:post, user: user, character: character)
      expect(post.icon).to be_nil
      login_as(user)

      get :edit, id: post.id

      expect(response.status).to eq(200)
      expect(assigns(:post)).to eq(post)
      expect(assigns(:post).character).to eq(character)
      expect(assigns(:post).icon).to be_nil
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, id: -1
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid post" do
      login
      put :update, id: -1
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post be visible to user" do
      post = create(:post, privacy: Post::PRIVACY_PRIVATE)
      user = create(:user)
      login_as(user)
      expect(post.visible_to?(user)).not_to be_true

      put :update, id: post.id
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    context "mark unread" do
      it "requires valid at_id" do
        skip "TODO does not notify"
      end

      it "requires post's at_id" do
        skip "TODO does not notify"
      end

      it "notifies Marri about board_read" do
        # TODO fix the board_read thing better
        post = create(:post)
        post.mark_read(post.user, post.created_at)
        unread_reply = create(:reply, post: post)
        reply = create(:reply, post: post)
        time = Time.now
        post.board.mark_read(post.user, time)

        login_as(post.user)
        create(:admin_user) # to receive the alert message
        expect {
          put :update, id: post.id, unread: true, at_id: unread_reply.id
        }.to change{ Message.count }.by(1)

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:error]).to eq("You have marked this continuity read more recently than that reply was written; it will not appear in your Unread posts.")
        expect(post.reload.last_read(post.user)).to be_the_same_time_as(post.created_at)
      end

      it "works with at_id" do
        post = create(:post)
        unread_reply = create(:reply, post: post)
        reply = create(:reply, post: post)
        time = Time.now
        post.mark_read(post.user, time)
        expect(post.last_read(post.user)).to be_the_same_time_as(time)
        login_as(post.user)

        put :update, id: post.id, unread: true, at_id: unread_reply.id

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("Post has been marked as read until reply ##{unread_reply.id}.")
        expect(post.reload.last_read(post.user)).to be_the_same_time_as((unread_reply.created_at - 1.second))
      end

      it "works without at_id" do
        post = create(:post)
        user = create(:user)
        post.mark_read(user)
        expect(post.reload.send(:view_for, user)).not_to be_nil
        login_as(user)

        put :update, id: post.id, unread: true

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("Post has been marked as unread")
        expect(post.reload.first_unread_for(user)).to eq(post)
      end
    end

    context "change status" do
      it "requires permission" do
        post = create(:post)
        login
        put :update, id: post.id, status: 'complete'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("You do not have permission to modify this post.")
        expect(post.reload).to be_active
      end

      it "requires valid status" do
        post = create(:post)
        login_as(post.user)
        put :update, id: post.id, status: 'invalid'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("Invalid status selected.")
        expect(post.reload).to be_active
      end

      {complete: 'completed', abandoned: 'abandoned', hiatus: 'on_hiatus', active: 'active'}.each do |status, method|
        context "to #{status}" do
          let(:post) { create(:post) }

          it "works for creator" do
            login_as(post.user)
            put :update, id: post.id, status: status
            expect(response).to redirect_to(post_url(post))
            expect(flash[:success]).to eq("Post has been marked #{status}.")
            expect(post.reload.send("#{method}?")).to be_true
          end

          it "works for coauthor" do
            reply = create(:reply, post: post)
            login_as(reply.user)
            put :update, id: post.id, status: status
            expect(response).to redirect_to(post_url(post))
            expect(flash[:success]).to eq("Post has been marked #{status}.")
            expect(post.reload.send("#{method}?")).to be_true
          end

          it "works for admin" do
            login_as(create(:admin_user))
            put :update, id: post.id, status: status
            expect(response).to redirect_to(post_url(post))
            expect(flash[:success]).to eq("Post has been marked #{status}.")
            expect(post.reload.send("#{method}?")).to be_true
          end
        end
      end

      context "with an old thread" do
        {hiatus: 'on_hiatus', active: 'active'}.each do |status, method|
          context "to #{status}" do
            time = 2.months.ago
            let(:post) { create(:post, created_at: time, updated_at: time) }
            let(:reply) { create(:reply, post: post, created_at: time, updated_at: time) }
            before (:each) { reply }

            it "works for creator" do
              login_as(post.user)
              expect(post.reload.tagged_at).to be_the_same_time_as(time)
              put :update, id: post.id, status: status
              expect(response).to redirect_to(post_url(post))
              expect(flash[:success]).to eq("Post has been marked #{status}.")
              expect(post.reload.send("on_hiatus?")).to be_true
              expect(post.reload.send("marked_hiatus?")).to eq(status == :hiatus)
            end

            it "works for coauthor" do
              login_as(reply.user)
              expect(post.reload.tagged_at).to be_the_same_time_as(time)
              put :update, id: post.id, status: status
              expect(response).to redirect_to(post_url(post))
              expect(flash[:success]).to eq("Post has been marked #{status}.")
              expect(post.reload.send("on_hiatus?")).to be_true
              expect(post.reload.send("marked_hiatus?")).to eq(status == :hiatus)
            end

            it "works for admin" do
              login_as(create(:admin_user))
              expect(post.reload.tagged_at).to be_the_same_time_as(time)
              put :update, id: post.id, status: status
              expect(response).to redirect_to(post_url(post))
              expect(flash[:success]).to eq("Post has been marked #{status}.")
              expect(post.reload.send("on_hiatus?")).to be_true
              expect(post.reload.send("marked_hiatus?")).to eq(status == :hiatus)
            end
          end
        end
      end
    end

    context "author lock" do
      let(:post) { create(:post, authors_locked: false) }

      it "requires permission" do
        login
        put :update, id: post.id, authors_locked: 'true'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("You do not have permission to modify this post.")
        expect(post.reload).not_to be_authors_locked
      end

      it "works for creator" do
        login_as(post.user)
        put :update, id: post.id, authors_locked: 'true'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been locked to current authors.")
        expect(post.reload).to be_authors_locked

        put :update, id: post.id, authors_locked: 'false'
        expect(flash[:success]).to eq("Post has been unlocked from current authors.")
        expect(post.reload).not_to be_authors_locked
      end

      it "works for coauthor" do
        reply = create(:reply, post: post)
        login_as(reply.user)
        put :update, id: post.id, authors_locked: 'true'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been locked to current authors.")
        expect(post.reload).to be_authors_locked

        put :update, id: post.id, authors_locked: 'false'
        expect(flash[:success]).to eq("Post has been unlocked from current authors.")
        expect(post.reload).not_to be_authors_locked
      end

      it "works for admin" do
        login_as(create(:admin_user))
        put :update, id: post.id, authors_locked: 'true'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been locked to current authors.")
        expect(post.reload).to be_authors_locked

        put :update, id: post.id, authors_locked: 'false'
        expect(flash[:success]).to eq("Post has been unlocked from current authors.")
        expect(post.reload).not_to be_authors_locked
      end
    end

    context "mark hidden" do
      it "marks hidden" do
        post = create(:post)
        reply = create(:reply, post: post)
        user = create(:user)
        post.mark_read(user, post.read_time_for([reply]))
        time_read = post.reload.last_read(user)

        login_as(user)
        expect(post.ignored_by?(user)).not_to be_true

        put :update, id: post.id, hidden: 'true'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been hidden")
        expect(post.reload.ignored_by?(user)).to be_true
        expect(post.last_read(user)).to be_the_same_time_as(time_read)
      end

      it "marks unhidden" do
        post = create(:post)
        reply = create(:reply, post: post)
        user = create(:user)
        login_as(user)
        post.mark_read(user, post.read_time_for([reply]))
        time_read = post.reload.last_read(user)

        post.ignore(user)
        expect(post.reload.ignored_by?(user)).to be_true

        put :update, id: post.id, hidden: 'false'
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been unhidden")
        expect(post.reload.ignored_by?(user)).not_to be_true
        expect(post.last_read(user)).to be_the_same_time_as(time_read)
      end
    end

    context "preview" do
      skip "TODO"
    end

    context "make changes" do
      it "creates new tags if needed" do
        skip "TODO"
      end

      it "requires valid update" do
        post = create(:post)
        newcontent = post.content + 'new'
        login_as(post.user)
        put :update, id: post.id, post: {subject: ''}
        expect(response).to render_template(:edit)
        expect(flash[:error][:message]).to eq("Your post could not be saved because of the following problems:")
        expect(post.reload.subject).not_to be_empty
        # TODO check editor setup
      end

      it "works" do
        post = create(:post)
        newcontent = post.content + 'new'
        login_as(post.user)
        put :update, id: post.id, post: {content: newcontent}
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Your post has been updated.")
        expect(post.reload.content).to eq(newcontent)
      end
    end
  end

  describe "POST warnings" do
    it "requires a valid post" do
      post :warnings, id: -1
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires permission" do
      warn_post = create(:post, privacy: Post::PRIVACY_PRIVATE)
      post :warnings, id: warn_post.id
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "works for logged out" do
      warn_post = create(:post)
      expect(session[:ignore_warnings]).to be_nil
      post :warnings, id: warn_post.id, per_page: 10, page: 2
      expect(response).to redirect_to(post_url(warn_post, per_page: 10, page: 2))
      expect(flash[:success]).to eq("All content warnings have been hidden. Proceed at your own risk.")
      expect(session[:ignore_warnings]).to be_true
    end

    it "works for logged in" do
      warn_post = create(:post)
      user = create(:user)
      expect(session[:ignore_warnings]).to be_nil
      expect(warn_post.send(:view_for, user)).to be_a_new_record
      login_as(user)
      post :warnings, id: warn_post.id
      expect(response).to redirect_to(post_url(warn_post))
      expect(flash[:success]).to start_with("Content warnings have been hidden for this thread. Proceed at your own risk.")
      expect(session[:ignore_warnings]).to be_nil
      view = warn_post.reload.send(:view_for, user)
      expect(view).not_to be_a_new_record
      expect(view.warnings_hidden).to be_true
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, id: -1
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid post" do
      login
      delete :destroy, id: -1
      expect(response).to redirect_to(boards_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post permission" do
      user = create(:user)
      login_as(user)
      post = create(:post)
      expect(post).not_to be_editable_by(user)
      delete :destroy, id: post.id
      expect(response).to redirect_to(post_url(post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "succeeds" do
      post = create(:post)
      login_as(post.user)
      delete :destroy, id: post.id
      expect(response).to redirect_to(boards_url)
      expect(flash[:success]).to eq("Post deleted.")
    end
  end

  describe "GET owed" do
    it "requires login" do
      get :owed
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds" do
      login
      get :owed
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq('Tags Owed')
    end

    context "with posts" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      before(:each) do
        other_user
        login_as(user)
      end

      it "shows a post if replied to by someone else" do
        post = create(:post, user_id: user.id)
        create(:reply, post_id: post.id, user_id: other_user.id)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "hides a post if you reply to it" do
        post = create(:post, user_id: user.id)
        create(:reply, post_id: post.id, user_id: other_user.id)
        create(:reply, post_id: post.id, user_id: user.id)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "does not show posts from site_testing" do
        skip "not sure how to create a board with a particular ID"
      end

      it "hides completed and abandoned threads" do
        post = create(:post, user_id: user.id)
        create(:reply, post_id: post.id, user_id: other_user.id)

        post.update_attributes(status: Post::STATUS_COMPLETE)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty

        post.update_attributes(status: Post::STATUS_ACTIVE)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])

        post.update_attributes(status: Post::STATUS_ABANDONED)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "show hiatused threads by default" do
        post = create(:post, user_id: user.id)
        create(:reply, post_id: post.id, user_id: other_user.id)
        post.update_attributes(status: Post::STATUS_HIATUS)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "optionally hides hiatused threads" do
        post = create(:post, user_id: user.id)
        create(:reply, post_id: post.id, user_id: other_user.id)
        post.update_attributes(status: Post::STATUS_HIATUS)

        user.hide_hiatused_tags_owed = true
        user.save
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end
    end

    # TODO more tests
  end

  describe "GET unread" do
    it "requires login" do
      get :unread
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds" do
      login
      get :unread
      expect(response).to have_http_status(200)
      expect(assigns(:started)).not_to be_true
      expect(assigns(:page_title)).to eq('Unread Threads')
      expect(assigns(:posts)).to be_empty
      expect(assigns(:hide_quicklinks)).to be_true
    end

    it "shows appropriate posts" do
      user = create(:user)
      time = Time.now - 10.minutes

      unread_post = create(:post) # post
      opened_post1, opened_post2, reply1, read_post1, read_post2, hidden_post = Timecop.freeze(time) do
        opened_post1 = create(:post) # post & reply, read post
        opened_post2 = create(:post) # post & 2 replies, read post & reply
        reply1 = create(:reply, post: opened_post2)
        read_post1 = create(:post) # post
        read_post2 = create(:post) # post & reply
        hidden_post = create(:post) # post
        [opened_post1, opened_post2, reply1, read_post1, read_post2, hidden_post]
      end
      reply2, reply3, reply4 = Timecop.freeze(time + 5.minutes) do
        reply2 = create(:reply, post: opened_post1)
        reply3 = create(:reply, post: opened_post2)
        reply4 = create(:reply, post: read_post2)
        [reply2, reply3, reply4]
      end

      opened_post1.mark_read(user, time)
      opened_post2.mark_read(user, time)
      read_post1.mark_read(user)
      read_post2.mark_read(user)
      hidden_post.ignore(user)

      expect(unread_post.reload.first_unread_for(user)).to eq(unread_post)
      expect(opened_post1.reload.first_unread_for(user)).to eq(reply2)
      expect(opened_post2.reload.first_unread_for(user)).to eq(reply3)
      expect(read_post1.reload.first_unread_for(user)).to be_nil
      expect(read_post2.reload.first_unread_for(user)).to be_nil
      expect(hidden_post.reload).to be_ignored_by(user)

      login_as(user)
      get :unread
      expect(response).to have_http_status(200)
      expect(assigns(:started)).not_to be_true
      expect(assigns(:page_title)).to eq('Unread Threads')
      expect(assigns(:posts)).to match_array([unread_post, opened_post1, opened_post2])
      expect(assigns(:hide_quicklinks)).to be_true
    end

    context "opened" do
      it "accepts parameter to force opened mode" do
        user = create(:user)
        expect(user.unread_opened).not_to be_true
        login_as(user)
        get :unread, started: 'true'
        expect(response).to have_http_status(200)
        expect(assigns(:started)).to be_true
        expect(assigns(:page_title)).to eq('Opened Threads')
      end

      it "shows appropriate posts" do
        user = create(:user, unread_opened: true)
        time = Time.now - 10.minutes

        unread_post = create(:post) # post
        opened_post1, opened_post2, reply1, read_post1, read_post2, hidden_post = Timecop.freeze(time) do
          opened_post1 = create(:post) # post & reply, read post
          opened_post2 = create(:post) # post & 2 replies, read post & reply
          reply1 = create(:reply, post: opened_post2)
          read_post1 = create(:post) # post
          read_post2 = create(:post) # post & reply
          hidden_post = create(:post) # post & reply
          [opened_post1, opened_post2, reply1, read_post1, read_post2, hidden_post]
        end
        reply2, reply3, reply4, reply5 = Timecop.freeze(time + 5.minutes) do
          reply2 = create(:reply, post: opened_post1)
          reply3 = create(:reply, post: opened_post2)
          reply4 = create(:reply, post: read_post2)
          reply5 = create(:reply, post: hidden_post)
          [reply2, reply3, reply4, reply5]
        end

        opened_post1.mark_read(user, time)
        opened_post2.mark_read(user, time)
        read_post1.mark_read(user)
        read_post2.mark_read(user)
        hidden_post.mark_read(user, time)
        hidden_post.ignore(user)

        expect(unread_post.reload.first_unread_for(user)).to eq(unread_post)
        expect(opened_post1.reload.first_unread_for(user)).to eq(reply2)
        expect(opened_post2.reload.first_unread_for(user)).to eq(reply3)
        expect(read_post1.reload.first_unread_for(user)).to be_nil
        expect(read_post2.reload.first_unread_for(user)).to be_nil
        expect(hidden_post.reload).to be_ignored_by(user)

        login_as(user)
        get :unread
        expect(response).to have_http_status(200)
        expect(assigns(:started)).to be_true
        expect(assigns(:page_title)).to eq('Opened Threads')
        expect(assigns(:posts)).to match_array([opened_post1, opened_post2])
        expect(assigns(:hide_quicklinks)).to be_true
      end
    end
  end

  describe "POST mark" do
    it "requires login" do
      post :mark
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    context "read" do
      it "skips invisible post" do
        private_post = create(:post, privacy: Post::PRIVACY_PRIVATE)
        user = create(:user)
        expect(private_post.visible_to?(user)).not_to be_true
        login_as(user)
        post :mark, marked_ids: [private_post.id], commit: "Mark Read"
        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("0 posts marked as read.")
        expect(private_post.reload.last_read(user)).to be_nil
      end

      it "reads posts" do
        user = create(:user)
        post1 = create(:post)
        post2 = create(:post)
        login_as(user)

        expect(post1.last_read(user)).to be_nil
        expect(post2.last_read(user)).to be_nil

        post :mark, marked_ids: [post1.id.to_s, post2.id.to_s], commit: "Mark Read"

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("2 posts marked as read.")
        expect(post1.reload.last_read(user)).not_to be_nil
        expect(post2.reload.last_read(user)).not_to be_nil
      end
    end

    context "ignored" do
      it "skips invisible post" do
        private_post = create(:post, privacy: Post::PRIVACY_PRIVATE)
        user = create(:user)
        expect(private_post.visible_to?(user)).not_to be_true
        login_as(user)
        post :mark, marked_ids: [private_post.id]
        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("0 posts hidden from this page.")
        expect(private_post.reload.ignored_by?(user)).not_to be_true
      end

      it "ignores posts" do
        user = create(:user)
        post1 = create(:post)
        post2 = create(:post)
        login_as(user)

        expect(post1.visible_to?(user)).to be_true
        expect(post2.visible_to?(user)).to be_true

        post :mark, marked_ids: [post1.id.to_s, post2.id.to_s]

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("2 posts hidden from this page.")
        expect(post1.reload.ignored_by?(user)).to be_true
        expect(post2.reload.ignored_by?(user)).to be_true
      end

      it "does not mess with read timestamps" do
        user = create(:user)

        time = Time.now - 10.minutes
        post1 = create(:post, created_at: time, updated_at: time) # unread
        post2 = create(:post, created_at: time, updated_at: time) # partially read
        post3 = create(:post, created_at: time, updated_at: time) # fully read
        replies1 = Array.new(5) { |i| create(:reply, post: post1, created_at: time + i.minutes, updated_at: time + i.minutes) }
        replies2 = Array.new(5) { |i| create(:reply, post: post2, created_at: time + i.minutes, updated_at: time + i.minutes) }
        replies3 = Array.new(5) { |i| create(:reply, post: post3, created_at: time + i.minutes, updated_at: time + i.minutes) }

        login_as(user)
        expect(post1).to be_visible_to(user)
        expect(post2).to be_visible_to(user)
        expect(post3).to be_visible_to(user)

        time2 = replies2.first.updated_at
        time3 = replies3.last.updated_at
        post2.mark_read(user, time2)
        post3.mark_read(user, time3)

        expect(post1.reload.last_read(user)).to be_nil
        expect(post2.reload.last_read(user)).to be_the_same_time_as(time2)
        expect(post3.reload.last_read(user)).to be_the_same_time_as(time3)

        post :mark, marked_ids: [post1, post2, post3].map(&:id).map(&:to_s)

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("3 posts hidden from this page.")
        expect(post1.reload.last_read(user)).to be_nil
        expect(post2.reload.last_read(user)).to be_the_same_time_as(time2)
        expect(post3.reload.last_read(user)).to be_the_same_time_as(time3)
      end
    end
  end

  describe "GET hidden" do
    it "requires login" do
      get :hidden
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds with no hidden" do
      login
      get :hidden
      expect(response.status).to eq(200)
      expect(assigns(:hidden_boardviews)).to be_empty
      expect(assigns(:hidden_posts)).to be_empty
    end

    it "succeeds with board hidden" do
      user = create(:user)
      board = create(:board)
      board.ignore(user)
      login_as(user)
      get :hidden
      expect(response.status).to eq(200)
      expect(assigns(:hidden_boardviews)).not_to be_empty
      expect(assigns(:hidden_posts)).to be_empty
    end

    it "succeeds with post hidden" do
      user = create(:user)
      post = create(:post)
      post.ignore(user)
      login_as(user)
      get :hidden
      expect(response.status).to eq(200)
      expect(assigns(:hidden_boardviews)).to be_empty
      expect(assigns(:hidden_posts)).not_to be_empty
    end

    it "succeeds with both hidden" do
      user = create(:user)
      post = create(:post)
      post.ignore(user)
      post.board.ignore(user)
      login_as(user)
      get :hidden
      expect(response.status).to eq(200)
      expect(assigns(:hidden_boardviews)).not_to be_empty
      expect(assigns(:hidden_posts)).not_to be_empty
    end
  end

  describe "POST unhide" do
    it "requires login" do
      post :unhide
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds for posts" do
      hidden_post = create(:post)
      stay_hidden_post = create(:post)
      user = create(:user)
      hidden_post.ignore(user)
      stay_hidden_post.ignore(user)
      login_as(user)
      post :unhide, unhide_posts: [hidden_post.id]
      expect(response).to redirect_to(hidden_posts_url)
      hidden_post.reload
      stay_hidden_post.reload
      expect(hidden_post).not_to be_ignored_by(user)
      expect(stay_hidden_post).to be_ignored_by(user)
    end

    it "succeeds for board" do
      board = create(:board)
      stay_hidden_board = create(:board)
      user = create(:user)
      board.ignore(user)
      stay_hidden_board.ignore(user)
      login_as(user)
      post :unhide, unhide_boards: [board.id]
      expect(response).to redirect_to(hidden_posts_url)
      board.reload
      stay_hidden_board.reload
      expect(board).not_to be_ignored_by(user)
      expect(stay_hidden_board).to be_ignored_by(user)
    end

    it "succeeds for both" do
      board = create(:board)
      hidden_post = create(:post)
      user = create(:user)
      board.ignore(user)
      hidden_post.ignore(user)
      login_as(user)

      post :unhide, unhide_boards: [board.id], unhide_posts: [hidden_post.id]

      expect(response).to redirect_to(hidden_posts_url)
      board.reload
      hidden_post.reload
      expect(board).not_to be_ignored_by(user)
      expect(hidden_post).not_to be_ignored_by(user)
    end

    it "succeeds for neither" do
      login
      post :unhide
      expect(response).to redirect_to(hidden_posts_url)
    end
  end
end
