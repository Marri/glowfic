RSpec.describe PostsController do
  describe "GET index" do
    it "has a 200 status code" do
      get :index
      expect(response.status).to eq(200)
    end

    it "paginates" do
      create_list(:post, 26)
      get :index
      num_posts_fetched = controller.instance_variable_get('@posts').total_pages
      expect(num_posts_fetched).to eq(2)
    end

    it "only fetches most recent threads" do
      create_list(:post, 26)
      oldest = Post.ordered_by_id.first
      get :index
      ids_fetched = controller.instance_variable_get('@posts').map(&:id)
      expect(ids_fetched).not_to include(oldest.id)
    end

    it "only fetches most recent threads based on updated_at" do
      create_list(:post, 26)
      oldest = Post.ordered_by_id.first
      next_oldest = Post.ordered_by_id.second
      oldest.update!(status: :complete)
      get :index
      ids_fetched = controller.instance_variable_get('@posts').map(&:id)
      expect(ids_fetched.count).to eq(25)
      expect(ids_fetched).not_to include(next_oldest.id)
    end

    it "orders posts by tagged_at" do
      post2 = Timecop.freeze(Time.zone.now - 8.minutes) { create(:post) }
      post5 = Timecop.freeze(Time.zone.now - 2.minutes) { create(:post) }
      post1 = Timecop.freeze(Time.zone.now - 10.minutes) { create(:post) }
      post4 = Timecop.freeze(Time.zone.now - 4.minutes) { create(:post) }
      post3 = Timecop.freeze(Time.zone.now - 6.minutes) { create(:post) }
      get :index
      ids_fetched = controller.instance_variable_get('@posts').map(&:id)
      expect(ids_fetched).to eq([post5.id, post4.id, post3.id, post2.id, post1.id])
    end

    context "with views" do
      render_views

      it "sanitizes post descriptions" do
        create(:post, description: "<a href=\"/characters/1\">Name</a> and <a href=\"/characters/2\">Other Name</a> do a thing.")
        create(:post, description: "A & B do a thing")
        get :index
        expect(response.body).to include('title="Name and Other Name do a thing."')
        expect(response.body).to include('title="A &amp; B do a thing"')
      end
    end
  end

  describe "GET search" do
    context "no search" do
      it "works logged out" do
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Posts')
        expect(assigns(:search_results)).to be_nil
      end

      it "works logged in" do
        login
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Posts')
        expect(assigns(:search_results)).to be_nil
      end
    end

    context "searching" do
      it "finds all when no arguments given" do
        create_list(:post, 4)
        get :search, params: { commit: true }
        expect(assigns(:search_results)).to match_array(Post.all)
      end

      it "filters by continuity" do
        post = create(:post)
        post2 = create(:post, board: post.board)
        create(:post)
        get :search, params: { commit: true, board_id: post.board_id }
        expect(assigns(:search_results)).to match_array([post, post2])
      end

      it "filters by setting" do
        setting = create(:setting)
        post = create(:post)
        post.settings << setting
        create(:post)
        get :search, params: { commit: true, setting_id: setting.id }
        expect(assigns(:search_results)).to match_array([post])
      end

      it "filters by subject" do
        post1 = create(:post, subject: 'contains stars')
        post2 = create(:post, subject: 'contains Stars cased')
        create(:post, subject: 'unrelated')
        get :search, params: { commit: true, subject: 'stars' }
        expect(assigns(:search_results)).to match_array([post1, post2])
      end

      it "restricts to visible posts" do
        create(:post, subject: 'contains stars', privacy: :private)
        post = create(:post, subject: 'visible contains stars')
        get :search, params: { commit: true, subject: 'stars' }
        expect(assigns(:search_results)).to match_array([post])
      end

      it "filters by exact match subject" do
        skip "TODO not yet implemented"
      end

      it "filters by authors" do
        posts = Array.new(4) { create(:post) }
        filtered_post = posts.last
        first_post = posts.first
        create(:reply, post: first_post, user: filtered_post.user)
        get :search, params: { commit: true, author_id: [filtered_post.user_id] }
        expect(assigns(:search_results)).to match_array([filtered_post, first_post])
      end

      it "filters by multiple authors" do
        author1 = create(:user)
        author2 = create(:user)
        nonauthor = create(:user)

        found_posts = []
        create(:post, user: author1) # one author but not the other, post
        post = create(:post, user: nonauthor) # one author but not the other, reply
        create(:reply, user: author2, post: post)

        post = create(:post, user: author1) # both authors, one post only
        create(:reply, post: post, user: author2)
        found_posts << post

        post = create(:post, user: nonauthor) # both authors, replies only
        create(:reply, post: post, user: author1)
        create(:reply, post: post, user: author2)
        found_posts << post

        get :search, params: { commit: true, author_id: [author1.id, author2.id] }
        expect(assigns(:search_results)).to match_array(found_posts)
      end

      it "filters by characters" do
        create(:reply, with_character: true)
        reply = create(:reply, with_character: true)
        post = create(:post, character: reply.character, user: reply.user)
        get :search, params: { commit: true, character_id: reply.character_id }
        expect(assigns(:search_results)).to match_array([reply.post, post])
      end

      it "filters by completed" do
        create(:post)
        post = create(:post, status: :complete)
        get :search, params: { commit: true, completed: true }
        expect(assigns(:search_results)).to match_array(post)
      end

      it "sorts posts by tagged_at" do
        posts = Array.new(4) do create(:post) end
        create(:reply, post: posts[2])
        create(:reply, post: posts[1])
        get :search, params: { commit: true }
        expect(assigns(:search_results)).to eq([posts[1], posts[2], posts[3], posts[0]])
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
      char1 = create(:character, user: user, name: 'alphafirst')
      user.update!(active_character: char1)
      user.reload
      login_as(user)

      char2 = create(:character, user: user, name: 'alphasecond')
      char3 = create(:template_character, user: user)
      expect(controller).to receive(:editor_setup).and_call_original
      expect(controller).to receive(:setup_layout_gon).and_call_original

      get :new

      expect(response).to have_http_status(200)
      expect(assigns(:post)).to be_new_record
      expect(assigns(:post).written.character).to eq(char1)

      # editor_setup:
      expect(assigns(:javascripts)).to include('posts/editor')
      expect(controller.gon.editor_user[:username]).to eq(user.username)

      # templates
      templates = assigns(:templates)
      expect(templates.length).to eq(2)
      template_chars = templates.first
      expect(template_chars).to eq(char3.template)
      templateless = templates.last
      expect(templateless.name).to eq('Templateless')
      expect(templateless.plucked_characters).to eq([[char1.id, char1.name], [char2.id, char2.name]])
    end

    context "import" do
      it "requires import permission" do
        login
        get :new, params: { view: :import }
        expect(response).to redirect_to(new_post_path)
        expect(flash[:error]).to eq('You do not have access to this feature.')
      end

      it "works for importer" do
        login_as(create(:importing_user))
        get :new, params: { view: :import }
        expect(response).to have_http_status(200)
      end
    end

    it "defaults authors to be the current user in open boards" do
      user = create(:user)
      login_as(user)
      create(:user) # user not in the board
      board_creator = create(:user) # user in the board
      board = create(:board, creator: board_creator, authors_locked: false)
      get :new, params: { board_id: board.id }
      expect(assigns(:post).board).to eq(board)
      expect(assigns(:author_ids)).to eq([])
    end

    it "defaults authors to be board authors in closed boards" do
      user = create(:user)
      login_as(user)
      coauthor = create(:user)
      create(:user) # other_user
      board = create(:board, creator: user, writers: [coauthor])
      get :new, params: { board_id: board.id }
      expect(assigns(:post).board).to eq(board)
      expect(assigns(:author_ids)).to match_array([coauthor.id])
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    context "scrape" do
      include ActiveJob::TestHelper
      it "requires valid user" do
        user = create(:user)
        login_as(user)
        post :create, params: { button_import: true }
        expect(response).to redirect_to(new_post_path)
        expect(flash[:error]).to eq("You do not have access to this feature.")
      end

      it "requires valid dreamwidth url" do
        user = create(:importing_user)
        login_as(user)
        post :create, params: { button_import: true, dreamwidth_url: 'http://www.google.com' }
        expect(response).to render_template(:new)
        expect(flash[:error]).to eq("Invalid URL provided.")
      end

      it "requires extant usernames" do
        clear_enqueued_jobs
        user = create(:importing_user)
        login_as(user)
        url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
        stub_fixture(url, 'scrape_no_replies')
        post :create, params: { button_import: true, dreamwidth_url: url }
        expect(response).to render_template(:new)
        expect(flash[:error][:message]).to start_with("The following usernames were not recognized")
        expect(flash[:error][:array]).to include("wild_pegasus_appeared")
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "scrapes" do
        clear_enqueued_jobs
        user = create(:importing_user)
        login_as(user)
        create(:character, user: user, screenname: 'wild-pegasus-appeared')
        url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
        stub_fixture(url, 'scrape_no_replies')
        post :create, params: { button_import: true, dreamwidth_url: url }
        expect(response).to redirect_to(posts_url)
        expect(flash[:success]).to eq("Post has begun importing. You will be updated on progress via site message.")
        expect(ScrapePostJob).to have_been_enqueued.with(url, nil, nil, nil, nil, user.id).on_queue('low')
      end
    end

    context "preview" do
      it "sets expected variables" do
        user = create(:user)
        login_as(user)
        setting1 = create(:setting)
        setting2 = create(:setting)
        warning1 = create(:content_warning)
        warning2 = create(:content_warning)
        label1 = create(:label)
        label2 = create(:label)
        char1 = create(:character, user: user)
        char2 = create(:template_character, user: user)
        icon = create(:icon)
        calias = create(:alias, character: char1)
        coauthor = create(:user)
        expect(controller).to receive(:editor_setup).and_call_original
        expect(controller).to receive(:setup_layout_gon).and_call_original
        post :create, params: {
          button_preview: true,
          post: {
            subject: 'test',
            setting_ids: [setting1.id, '_'+setting2.name, '_other'],
            content_warning_ids: [warning1.id, '_'+warning2.name, '_other'],
            label_ids: [label1.id, '_'+label2.name, '_other'],
            unjoined_author_ids: [user.id, coauthor.id]
          },
          reply: {
            content: 'orign',
            character_id: char1.id,
            icon_id: icon.id,
            character_alias_id: calias.id
          }
        }
        expect(response).to render_template(:preview)
        expect(assigns(:post).written).to be_an_instance_of(Reply)
        expect(assigns(:post).written).to be_a_new_record
        expect(assigns(:post).written.user).to eq(user)
        expect(assigns(:post).written.character).to eq(char1)
        expect(assigns(:post).written.icon).to eq(icon)
        expect(assigns(:post).written.character_alias).to eq(calias)
        expect(assigns(:page_title)).to eq('Previewing: test')
        expect(assigns(:author_ids)).to match_array([user.id, coauthor.id])

        # tags
        expect(assigns(:post).settings.size).to eq(0)
        expect(assigns(:post).content_warnings.size).to eq(0)
        expect(assigns(:post).labels.size).to eq(0)
        expect(assigns(:settings).map(&:id_for_select)).to match_array([setting1.id, setting2.id, '_other'])
        expect(assigns(:content_warnings).map(&:id_for_select)).to match_array([warning1.id, warning2.id, '_other'])
        expect(assigns(:labels).map(&:id_for_select)).to match_array([label1.id, label2.id, '_other'])
        expect(Setting.count).to eq(2)
        expect(ContentWarning.count).to eq(2)
        expect(Label.count).to eq(2)
        expect(PostTag.count).to eq(0)

        # editor_setup:
        expect(assigns(:javascripts)).to include('posts/editor')
        expect(controller.gon.editor_user[:username]).to eq(user.username)

        # templates
        templates = assigns(:templates)
        expect(templates.length).to eq(3)
        thread_chars = templates.first
        expect(thread_chars.name).to eq('Thread characters')
        expect(thread_chars.plucked_characters).to eq([[char1.id, char1.name]])
        template_chars = templates[1]
        expect(template_chars).to eq(char2.template)
        templateless = templates.last
        expect(templateless.name).to eq('Templateless')
        expect(templateless.plucked_characters).to eq([[char1.id, char1.name]])
      end

      it "does not crash without arguments" do
        user = create(:user)
        login_as(user)
        post :create, params: { button_preview: true }
        expect(response).to render_template(:preview)
        expect(assigns(:post).written).to be_an_instance_of(Reply)
        expect(assigns(:post).written).to be_a_new_record
        expect(assigns(:post).written.user).to eq(user)
      end

      it "does not create authors or viewers" do
        user = create(:user)
        login_as(user)

        coauthor = create(:user)
        board = create(:board, creator: user, authors_locked: true)

        expect {
          post :create, params: {
            button_preview: true,
            post: {
              subject: 'test subject',
              privacy: :access_list,
              board_id: board.id,
              unjoined_author_ids: [coauthor.id],
              viewer_ids: [coauthor.id, create(:user).id],
              content: 'test content',
            },
          }
        }.not_to change { [Post::Author.count, PostViewer.count, BoardAuthor.count] }

        expect(flash[:error]).to be_nil
        expect(assigns(:page_title)).to eq('Previewing: ' + assigns(:post).subject.to_s)
      end
    end

    it "creates new labels" do
      existing_name = create(:label)
      existing_case = create(:label)
      tags = ['_atag', '_atag', create(:label).id, '', '_' + existing_name.name, '_' + existing_case.name.upcase]
      login
      expect {
        post :create, params: { post: {subject: 'a', board_id: create(:board).id, label_ids: tags} }
      }.to change{Label.count}.by(1)
      expect(Label.last.name).to eq('atag')
      expect(assigns(:post).labels.count).to eq(4)
    end

    it "creates new settings" do
      existing_name = create(:setting)
      existing_case = create(:setting)
      tags = [
        '_atag',
        '_atag',
        create(:setting).id,
        '',
        '_' + existing_name.name,
        '_' + existing_case.name.upcase
      ]
      login
      expect {
        post :create, params: { post: {subject: 'a', board_id: create(:board).id, setting_ids: tags} }
      }.to change{Setting.count}.by(1)
      expect(Setting.last.name).to eq('atag')
      expect(assigns(:post).settings.count).to eq(4)
    end

    it "creates new content warnings" do
      existing_name = create(:content_warning)
      existing_case = create(:content_warning)
      tags = [
        '_atag',
        '_atag',
        create(:content_warning).id,
        '',
        '_' + existing_name.name,
        '_' + existing_case.name.upcase
      ]
      login
      expect {
        post :create, params: {
          post: {subject: 'a', board_id: create(:board).id, content_warning_ids: tags}
        }
      }.to change{ContentWarning.count}.by(1)
      expect(ContentWarning.last.name).to eq('atag')
      expect(assigns(:post).content_warnings.count).to eq(4)
    end

    it "creates new post authors correctly" do
      user = create(:user)
      other_user = create(:user)
      create(:user) # user should not be author
      board_creator = create(:user) # user should not be author
      board = create(:board, creator: board_creator)
      login_as(user)

      time = Time.zone.now - 5.minutes
      Timecop.freeze(time) do
        expect {
          post :create, params: {
            post: {
              subject: 'a',
              user_id: user.id,
              board_id: board.id,
              unjoined_author_ids: [other_user.id],
              private_note: 'there is a note!'
            }
          }
        }.to change { Post::Author.count }.by(2)
      end

      post = assigns(:post).reload
      expect(post.tagging_authors).to match_array([user, other_user])

      post_author = post.author_for(user)
      expect(post_author.can_owe).to eq(true)
      expect(post_author.joined).to eq(true)
      expect(post_author.joined_at).to be_the_same_time_as(time)
      expect(post_author.private_note).to eq('there is a note!')

      other_post_author = post.author_for(other_user)
      expect(other_post_author.can_owe).to eq(true)
      expect(other_post_author.joined).to eq(false)
      expect(other_post_author.joined_at).to be_nil
    end

    it "handles post submitted with no authors" do
      user = create(:user)
      create(:user) # non-author
      board_creator = create(:user)
      board = create(:board, creator: board_creator)
      login_as(user)

      time = Time.zone.now - 5.minutes
      Timecop.freeze(time) do
        expect {
          post :create, params: {
            post: {
              subject: 'a',
              user_id: user.id,
              board_id: board.id,
              unjoined_author_ids: ['']
            }
          }
        }.to change { Post::Author.count }.by(1)
      end

      post = assigns(:post).reload
      expect(post.tagging_authors).to eq([post.user])
      expect(post.authors).to match_array([user])

      post_author = post.post_authors.first
      expect(post_author.can_owe).to eq(true)
      expect(post_author.joined).to eq(true)
      expect(post_author.joined_at).to be_the_same_time_as(time)
    end

    it "adds new post authors to board cameo" do
      user = create(:user)
      other_user = create(:user)
      third_user = create(:user)
      create(:user) # separate user
      board = create(:board, creator: user, writers: [other_user])

      login_as(user)
      expect {
        post :create, params: {
          post: {
            subject: 'a',
            user_id: user.id,
            board_id: board.id,
            unjoined_author_ids: [user.id, other_user.id, third_user.id]
          }
        }
      }.to change { BoardAuthor.count }.by(1)

      post = assigns(:post).reload
      expect(post.tagging_authors).to match_array([user, other_user, third_user])

      board.reload
      expect(board.writers).to match_array([user, other_user])
      expect(board.cameos).to match_array([third_user])
    end

    it "does not add to cameos of open boards" do
      user = create(:user)
      other_user = create(:user)
      board = create(:board)
      expect(board.cameos).to be_empty

      login_as(user)
      expect {
        post :create, params: {
          post: {
            subject: 'a',
            user_id: user.id,
            board_id: board.id,
            unjoined_author_ids: [user.id, other_user.id]
          }
        }
      }.not_to change { BoardAuthor.count }

      post = assigns(:post).reload
      expect(post.tagging_authors).to match_array([user, other_user])

      board.reload
      expect(board.writers).to eq([board.creator])
      expect(board.cameos).to be_empty
    end

    it "handles new post authors already being in cameos" do
      user = create(:user)
      other_user = create(:user)
      board = create(:board, creator: user, cameos: [other_user])

      login_as(user)
      post :create, params: {
        post: {
          subject: 'a',
          user_id: user.id,
          board_id: board.id,
          unjoined_author_ids: [user.id, other_user.id]
        }
      }

      expect(flash[:success]).to eq("You have successfully posted.")
      post = assigns(:post).reload
      expect(post.tagging_authors).to match_array([user, other_user])

      board.reload
      expect(board.creator).to eq(user)
      expect(board.cameos).to match_array([other_user])
    end

    it "handles invalid posts" do
      user = create(:user)
      login_as(user)
      setting1 = create(:setting)
      setting2 = create(:setting)
      warning1 = create(:content_warning)
      warning2 = create(:content_warning)
      label1 = create(:label)
      label2 = create(:label)
      char1 = create(:character, user: user)
      char2 = create(:template_character, user: user)
      coauthor = create(:user)
      expect(controller).to receive(:editor_setup).and_call_original
      expect(controller).to receive(:setup_layout_gon).and_call_original

      # valid post requires a board_id
      post :create, params: {
        post: {
          subject: 'asubjct',
          setting_ids: [setting1.id, '_'+setting2.name, '_other'],
          content_warning_ids: [warning1.id, '_'+warning2.name, '_other'],
          label_ids: [label1.id, '_'+label2.name, '_other'],
          unjoined_author_ids: [user.id, coauthor.id]
        },
        reply: {
          content: 'acontnt',
          character_id: char1.id
        }
      }

      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Your post could not be saved because of the following problems:")
      expect(assigns(:post)).not_to be_persisted
      expect(assigns(:post).user).to eq(user)
      expect(assigns(:post).subject).to eq('asubjct')
      expect(assigns(:post).written.content).to eq('acontnt')
      expect(assigns(:page_title)).to eq('New Post')
      expect(assigns(:author_ids)).to match_array([user.id, coauthor.id])

      # editor_setup:
      expect(assigns(:javascripts)).to include('posts/editor')
      expect(controller.gon.editor_user[:username]).to eq(user.username)

      # templates
      templates = assigns(:templates)
      expect(templates.length).to eq(3)
      thread_chars = templates.first
      expect(thread_chars.name).to eq('Thread characters')
      expect(thread_chars.plucked_characters).to eq([[char1.id, char1.name]])
      template_chars = templates[1]
      expect(template_chars).to eq(char2.template)
      templateless = templates.last
      expect(templateless.name).to eq('Templateless')
      expect(templateless.plucked_characters).to eq([[char1.id, char1.name]])

      # tags
      expect(assigns(:post).settings.size).to eq(3)
      expect(assigns(:post).content_warnings.size).to eq(3)
      expect(assigns(:post).labels.size).to eq(3)
      expect(assigns(:post).settings.map(&:id_for_select)).to match_array([setting1.id, setting2.id, '_other'])
      expect(assigns(:post).content_warnings.map(&:id_for_select)).to match_array([warning1.id, warning2.id, '_other'])
      expect(assigns(:post).labels.map(&:id_for_select)).to match_array([label1.id, label2.id, '_other'])
      expect(Setting.count).to eq(2)
      expect(ContentWarning.count).to eq(2)
      expect(Label.count).to eq(2)
      expect(PostTag.count).to eq(0)
    end

    it "handles invalid first reply" do
      skip "it is not currently possible for this reply to be invalid"
    end

    it "creates a post" do
      user = create(:user)
      login_as(user)
      board = create(:board)
      section = create(:board_section, board: board)
      char = create(:character, user: user)
      icon = create(:icon, user: user)
      calias = create(:alias, character: char)
      viewer = create(:user)
      setting1 = create(:setting)
      setting2 = create(:setting)
      warning1 = create(:content_warning)
      warning2 = create(:content_warning)
      label1 = create(:label)
      label2 = create(:label)
      coauthor = create(:user)

      expect {
        post :create, params: {
          post: {
            subject: 'asubjct',
            description: 'adesc',
            board_id: board.id,
            section_id: section.id,
            privacy: :access_list,
            viewer_ids: [viewer.id],
            setting_ids: [setting1.id, '_'+setting2.name, '_other'],
            content_warning_ids: [warning1.id, '_'+warning2.name, '_other'],
            label_ids: [label1.id, '_'+label2.name, '_other'],
            unjoined_author_ids: [coauthor.id]
          },
          reply: {
            content: 'acontnt',
            character_id: char.id,
            icon_id: icon.id,
            character_alias_id: calias.id,
          }
        }
      }.to change{Post.count}.by(1)
      expect(response).to redirect_to(post_path(assigns(:post)))
      expect(flash[:success]).to eq("You have successfully posted.")

      post = assigns(:post).reload
      expect(post).to be_persisted
      expect(post.user).to eq(user)
      expect(post.last_user).to eq(user)
      expect(post.subject).to eq('asubjct')
      expect(post.written.content).to eq('acontnt')
      expect(post.description).to eq('adesc')
      expect(post.board).to eq(board)
      expect(post.section).to eq(section)
      expect(post.written.character_id).to eq(char.id)
      expect(post.written.icon_id).to eq(icon.id)
      expect(post.written.character_alias_id).to eq(calias.id)
      expect(post).to be_privacy_access_list
      expect(post.viewers).to match_array([viewer])
      expect(post.reload).to be_visible_to(viewer)
      expect(post.reload).not_to be_visible_to(create(:user))

      expect(post.authors).to match_array([user, coauthor])
      expect(post.tagging_authors).to match_array([user, coauthor])
      expect(post.unjoined_authors).to match_array([coauthor])
      expect(post.joined_authors).to match_array([user])

      # tags
      expect(post.settings.size).to eq(3)
      expect(post.content_warnings.size).to eq(3)
      expect(post.labels.size).to eq(3)
      expect(post.settings.map(&:id_for_select)).to match_array([setting1.id, setting2.id, Setting.last.id])
      expect(post.content_warnings.map(&:id_for_select)).to match_array([warning1.id, warning2.id, ContentWarning.last.id])
      expect(post.labels.map(&:id_for_select)).to match_array([label1.id, label2.id, Label.last.id])
      expect(Setting.count).to eq(3)
      expect(ContentWarning.count).to eq(3)
      expect(Label.count).to eq(3)
      expect(PostTag.count).to eq(9)
    end

    it "generates a flat post" do
      user = create(:user)
      login_as(user)
      post :create, params: {
        post: {
          subject: 'subject',
          board_id: create(:board).id,
          privacy: :registered,
        },
        reply: {
          content: 'content',
        }
      }
      post = assigns(:post)
      expect(post.flat_post).not_to be_nil
    end

    context "with blocks" do
      let(:user) { create(:user) }
      let(:blocked) { create(:user) }
      let(:blocking) { create(:user) }
      let(:other_user) { create(:user) }
      let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

      before(:each) do
        create(:block, blocking_user: user, blocked_user: blocked, hide_me: :posts)
        create(:block, blocking_user: blocking, blocked_user: user, hide_them: :posts)
        allow(Rails).to receive(:cache).and_return(memory_store)
        Rails.cache.clear
      end

      it "regenerates blocked and hidden posts for poster" do
        expect(blocking.hidden_posts).to be_empty
        expect(blocked.blocked_posts).to be_empty

        login_as(user)

        post :create, params: {
          post: {
            subject: "subject",
            user_id: user.id,
            board_id: create(:board).id,
            authors_locked: true,
            unjoined_author_ids: [other_user.id],
          }
        }

        expect(Rails.cache.exist?(Block.cache_string_for(blocking.id, 'hidden'))).to be(false)
        expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

        post = assigns(:post)
        expect(blocking.hidden_posts).to eq([post.id])
        expect(blocked.blocked_posts).to eq([post.id])
      end

      it "regenerates blocked and hidden posts for coauthor" do
        expect(blocking.hidden_posts).to be_empty
        expect(blocked.blocked_posts).to be_empty

        login_as(other_user)

        post :create, params: {
          post: {
            subject: "subject",
            user_id: other_user.id,
            board_id: create(:board).id,
            authors_locked: true,
            unjoined_author_ids: [user.id],
          }
        }

        expect(Rails.cache.exist?(Block.cache_string_for(blocking.id, 'hidden'))).to be(false)
        expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

        post = assigns(:post)
        expect(blocking.hidden_posts).to eq([post.id])
        expect(blocked.blocked_posts).to eq([post.id])
      end
    end
  end

  describe "GET show" do
    it "does not require login" do
      post = create(:post)
      get :show, params: { id: post.id }
      expect(response).to have_http_status(200)
      expect(assigns(:javascripts)).to include('posts/show')
    end

    it "calculates OpenGraph meta" do
      user = create(:user, username: 'example user')
      board = create(:board, name: 'board')
      post = create(:post, subject: 'title', user: user, board: board)
      get :show, params: { id: post.id }

      meta_og = assigns(:meta_og)
      expect(meta_og[:url]).to eq(post_url(post))
      expect(meta_og[:title]).to eq('title · board')
      expect(meta_og[:description]).to eq('(example user – page 1 of 1)')
    end

    it "requires permission" do
      post = create(:post, privacy: :private)
      get :show, params: { id: post.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "works with login" do
      post = create(:post)
      login
      get :show, params: { id: post.id }
      expect(response).to have_http_status(200)
      expect(assigns(:javascripts)).to include('posts/show')
    end

    it "marks read multiple times" do
      post = create(:post)
      user = create(:user)
      login_as(user)
      expect(post.last_read(user)).to be_nil
      get :show, params: { id: post.id }
      last_read = post.reload.last_read(user)
      expect(last_read).not_to be_nil

      Timecop.freeze(last_read + 1.second) do
        reply = create(:reply, post: post)
        expect(reply.created_at).not_to be_the_same_time_as(last_read)
        get :show, params: { id: post.id }
        cur_read = post.reload.last_read(user)
        expect(last_read).not_to be_the_same_time_as(cur_read)
        expect(last_read.to_i).to be < cur_read.to_i
      end
    end

    it "marks read even if post is ignored" do
      post = create(:post)
      user = create(:user)
      login_as(user)
      post.ignore(user)
      expect(post.reload.first_unread_for(user)).to eq(post)

      get :show, params: { id: post.id }
      expect(post.reload.first_unread_for(user)).to be_nil
      last_read = post.last_read(user)

      Timecop.freeze(last_read + 1.second) do
        reply = create(:reply, post: post)
        expect(reply.created_at).not_to be_the_same_time_as(last_read)
        expect(post.reload.first_unread_for(user)).to eq(reply)
        get :show, params: { id: post.id }
        expect(post.reload.first_unread_for(user)).to be_nil
      end
    end

    it "handles invalid pages" do
      post = create(:post)
      get :show, params: { id: post.id, page: 'invalid' }
      expect(flash[:error]).to eq('Page not recognized, defaulting to page 1.')
      expect(assigns(:page)).to eq(1)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    it "handles invalid unread page when logged out" do
      post = create(:post)
      get :show, params: { id: post.id, page: 'unread' }
      expect(flash[:error]).to eq("You must be logged in to view unread posts.")
      expect(assigns(:page)).to eq(1)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    it "handles pages outside range" do
      post = create(:post)
      create_list(:reply, 5, post: post)
      get :show, params: { id: post.id, per_page: 1, page: 10 }
      expect(response).to redirect_to(post_url(post, page: 5, per_page: 1))
    end

    it "handles page=last with replies" do
      post = create(:post)
      create_list(:reply, 5, post: post)
      get :show, params: { id: post.id, per_page: 1, page: 'last' }
      expect(assigns(:page)).to eq(5)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    it "handles page=last with no replies" do
      post = create(:post)
      get :show, params: { id: post.id, page: 'last' }
      expect(assigns(:page)).to eq(1)
      expect(response).to have_http_status(200)
      expect(response).to render_template(:show)
    end

    it "calculates audits" do
      Reply.auditing_enabled = true
      Post.auditing_enabled = true
      post = create(:post)

      replies = Audited.audit_class.as_user(post.user) do
        create_list(:reply, 6, post: post, user: post.user)
      end

      Audited.audit_class.as_user(post.user) do
        replies[1].touch # rubocop:disable Rails/SkipsModelValidations
        replies[3].update!(character: create(:character, user: post.user))
        replies[2].update!(content: 'new content')
        1.upto(5) { |i| replies[4].update!(content: 'message' + i.to_s) }
      end
      Audited.audit_class.as_user(create(:mod_user)) do
        replies[5].update!(content: 'new content')
      end

      counts = replies.map(&:id).zip([1, 1, 2, 2, 6, 2]).to_h
      counts[:post] = 1

      get :show, params: { id: post.id }
      expect(assigns(:audits)).to eq(counts)
      Reply.auditing_enabled = false
      Post.auditing_enabled = false
    end

    context "with render_views" do
      render_views

      it "renders HAML with additional attributes" do
        post = create(:post, with_icon: true, with_character: true)
        create(:reply, post: post, with_icon: true, with_character: true)
        get :show, params: { id: post.id }
        expect(response.status).to eq(200)
        expect(response.body).to include(post.subject)
        expect(response.body).to include('header-right')
      end

      it "renders HAML for logged in user" do
        post = create(:post)
        create(:reply, post: post)
        character = create(:character)
        login_as(character.user)
        get :show, params: { id: post.id }
        expect(response.status).to eq(200)
        expect(response.body).to include('Join Thread')
      end

      it "flat view renders HAML properly" do
        post = create(:post, with_icon: true, with_character: true)
        create(:reply, post: post, with_icon: true, with_character: true)
        get :show, params: { id: post.id, view: 'flat' }
        expect(response.status).to eq(200)
        expect(response.body).to include(post.subject)
        expect(response.body).not_to include('header-right')
      end

      it "displays quick switch properly" do
        post = create(:post)
        reply = create(:reply, post: post, with_icon: true, with_character: true)
        login_as(reply.user)
        get :show, params: { id: post.id }
        expect(response.status).to eq(200)
      end
    end

    context "with at_id" do
      let(:post) { create(:post) }

      before(:each) do
        create_list(:reply, 5, post: post)
      end

      it "shows error if reply not found" do
        get :show, params: { id: post.id, at_id: -1 }
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "shows error if unread not logged in" do
        get :show, params: { id: post.id, at_id: 'unread' }
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "shows error if no unread" do
        user = create(:user)
        post.mark_read(user)
        login_as(user)
        get :show, params: { id: post.id, at_id: 'unread' }
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "shows error when reply is wrong post" do
        get :show, params: { id: post.id, at_id: create(:reply).id }
        expect(flash[:error]).to eq("Could not locate specified reply, defaulting to first page.")
        expect(assigns(:replies).count).to eq(5)
      end

      it "works for specified reply" do
        last_reply = post.replies.ordered.last
        get :show, params: { id: post.id, at_id: last_reply.id }
        expect(assigns(:replies)).to eq([last_reply])
        expect(assigns(:replies).current_page.to_i).to eq(1)
        expect(assigns(:replies).per_page).to eq(25)
      end

      it "works for specified reply with page settings" do
        second_last_reply = post.replies.ordered.last(2).first
        get :show, params: { id: post.id, at_id: second_last_reply.id, per_page: 1 }
        expect(assigns(:replies)).to eq([second_last_reply])
        expect(assigns(:replies).current_page.to_i).to eq(1)
        expect(assigns(:replies).per_page).to eq(1)
      end

      it "works for page settings incompatible with specified reply" do
        last_reply = post.replies.ordered.last
        second_last_reply = post.replies.ordered.last(2).first
        get :show, params: { id: post.id, at_id: second_last_reply.id, per_page: 1, page: 2 }
        expect(assigns(:replies)).to eq([last_reply])
        expect(assigns(:replies).current_page.to_i).to eq(2)
        expect(assigns(:replies).per_page).to eq(1)
      end

      it "works for unread" do
        third_reply = post.replies.ordered[3]
        second_last_reply = post.replies.ordered[-2]
        user = create(:user)
        post.mark_read(user, at_time: third_reply.created_at)
        expect(post.first_unread_for(user)).to eq(second_last_reply)
        login_as(user)
        get :show, params: { id: post.id, at_id: 'unread', per_page: 1 }
        expect(assigns(:replies)).to eq([second_last_reply])
        expect(assigns(:unread)).to eq(second_last_reply)
        expect(assigns(:paginate_params)['at_id']).to eq(second_last_reply.id)
      end
    end

    context "page=unread" do
      it "goes to the end if you're up to date" do
        post = create(:post)
        create_list(:reply, 3, post: post, user: post.user)
        user = create(:user)
        post.mark_read(user)
        login_as(user)
        get :show, params: { id: post.id, page: 'unread', per_page: 1 }
        expect(assigns(:page)).to eq(3)
      end

      it "goes to beginning if you've never read it" do
        post = create(:post)
        user = create(:user)
        login_as(user)
        get :show, params: { id: post.id, page: 'unread' }
        expect(assigns(:page)).to eq(1)
      end

      it "goes to post page if you're behind" do
        post = create(:post)
        reply1 = create(:reply, post: post, user: post.user)
        Timecop.freeze(reply1.created_at + 1.second) do create(:reply, post: post, user: post.user) end # second reply
        Timecop.freeze(reply1.created_at + 2.seconds) do create(:reply, post: post, user: post.user) end # third reply
        user = create(:user)
        post.mark_read(user, at_time: reply1.created_at)
        login_as(user)
        get :show, params: { id: post.id, page: 'unread', per_page: 1 }
        expect(assigns(:page)).to eq(2)
      end
    end

    context "with author" do
      it "works" do
        post = create(:post)
        login_as(post.user)
        get :show, params: { id: post.id }
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
        expect(post).to receive(:build_new_reply_for).with(user, {}).and_call_original
        expect(controller).to receive(:setup_layout_gon).and_call_original

        get :show, params: { id: post.id }
        expect(response).to have_http_status(200)
        expect(assigns(:reply)).not_to be_nil
        expect(assigns(:javascripts)).to include('posts/show', 'posts/editor')
      end
    end

    context "with non-author who can write" do
      it "works" do
        post = create(:post, authors_locked: false)
        user = create(:user)
        login_as(user)
        expect(post).to be_taggable_by(user)
        get :show, params: { id: post.id }
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
        expect(post).to receive(:build_new_reply_for).with(user, {}).and_call_original

        get :show, params: { id: post.id }
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

        get :show, params: { id: post.id }
        expect(response).to have_http_status(200)
        expect(assigns(:reply)).to be_nil
      end
    end
    # TODO WAY more tests
  end

  describe "GET history" do
    it "requires post" do
      login
      get :history, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "works logged out" do
      get :history, params: { id: create(:post).id }
      expect(response.status).to eq(200)
    end

    it "works logged in" do
      login
      get :history, params: { id: create(:post).id }
      expect(response.status).to eq(200)
    end

    context "with render_view" do
      render_views

      it "works" do
        Post.auditing_enabled = true
        post = create(:post)
        post.update!(privacy: :access_list)
        post.update!(board: create(:board))
        post.update!(content: 'new content')

        login_as(post.user)

        get :history, params: { id: post.id }

        expect(response.status).to eq(200)
        Post.auditing_enabled = false
      end
    end
  end

  describe "GET delete_history" do
    before(:each) { Reply.auditing_enabled = true }

    after(:each) { Reply.auditing_enabled = false }

    it "requires login" do
      get :delete_history, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires post" do
      login
      get :delete_history, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires permission" do
      login
      post = create(:post)
      get :delete_history, params: { id: post.id }
      expect(response).to redirect_to(post_url(post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "sets correct variables" do
      post = create(:post)
      login_as(post.user)
      reply = create(:reply, post: post)
      reply.destroy!
      get :delete_history, params: { id: post.id }
      expect(response).to have_http_status(200)
      expect(assigns(:audit).auditable_id).to eq(reply.id)
    end

    it "ignores restored replies" do
      post = create(:post)
      login_as(post.user)
      reply = create(:reply, post: post)
      reply.destroy!
      restore(reply)
      get :delete_history, params: { id: post.id }
      expect(assigns(:audits).count).to eq(0)
    end

    it "only selects more recent restore" do
      post = create(:post)
      login_as(post.user)
      reply = create(:reply, post: post, content: 'old content')
      reply.destroy!
      restore(reply)
      reply = Reply.find_by_id(reply.id)
      reply.content = 'new content'
      reply.save!
      reply.destroy!
      get :delete_history, params: { id: post.id }
      expect(assigns(:audits).count).to eq(1)
      expect(assigns(:audit).audited_changes['content']).to eq('new content')
    end

    def restore(reply)
      audit = Audited::Audit.where(action: 'destroy', auditable_id: reply.id).last
      new_reply = Reply.new(audit.audited_changes)
      new_reply.is_import = true
      new_reply.skip_notify = true
      new_reply.id = audit.auditable_id
      new_reply.save!
    end
  end

  describe "GET stats" do
    it "requires post" do
      login
      get :stats, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "works logged out" do
      get :stats, params: { id: create(:post).id }
      expect(response.status).to eq(200)
    end

    it "works logged in" do
      login
      get :stats, params: { id: create(:post).id }
      expect(response.status).to eq(200)
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires post" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires your post" do
      login
      post = create(:post)
      get :edit, params: { id: post.id }
      expect(response).to redirect_to(post_url(post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "sets relevant fields" do
      user = create(:user)
      char1 = create(:character, user: user)
      char2 = create(:character, user: user)
      char3 = create(:template_character, user: user)
      setting = create(:setting)
      warning = create(:content_warning)
      label = create(:label)
      unjoined = create(:user)
      post = create(:post,
        user: user,
        character: char1,
        settings: [setting],
        content_warnings: [warning],
        labels: [label],
        unjoined_authors: [unjoined],
      )
      expect(post.written.icon).to be_nil

      create(:reply, user: user, post: post, character: char2) # reply1

      coauthor = create(:user)
      create(:reply, user: coauthor, post: post) # other user's post

      ignored_author = create(:user)
      create(:reply, user: ignored_author, post: post) # ignored user's post
      post.opt_out_of_owed(ignored_author)

      login_as(user)

      # extras to not be in the array
      create(:setting)
      create(:content_warning)
      create(:label)
      create(:user)

      expect(controller).to receive(:editor_setup).and_call_original
      expect(controller).to receive(:setup_layout_gon).and_call_original

      get :edit, params: { id: post.id }

      expect(response.status).to eq(200)
      expect(assigns(:post)).to eq(post)
      expect(assigns(:post).written.character).to eq(char1)
      expect(assigns(:post).written.icon).to be_nil

      # editor_setup:
      expect(assigns(:javascripts)).to include('posts/editor')
      expect(controller.gon.editor_user[:username]).to eq(user.username)
      expect(assigns(:author_ids)).to match_array([unjoined.id])

      # templates
      templates = assigns(:templates)
      expect(templates.length).to eq(3)
      thread_chars = templates.first
      expect(thread_chars.name).to eq('Thread characters')
      expected = [char1, char2].sort_by{ |c| c.name.downcase }.map { |c| [c.id, c.name] }
      expect(thread_chars.plucked_characters).to eq(expected)
      template_chars = templates[1]
      expect(template_chars).to eq(char3.template)
      templateless = templates.last
      expect(templateless.name).to eq('Templateless')
      expect(templateless.plucked_characters).to eq(expected)

      # tags
      expect(assigns(:post).settings.map(&:id_for_select)).to match_array([setting.id])
      expect(assigns(:post).content_warnings.map(&:id_for_select)).to match_array([warning.id])
      expect(assigns(:post).labels.map(&:id_for_select)).to match_array([label.id])
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid post" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post be visible to user" do
      post = create(:post, privacy: :private)
      user = create(:user)
      login_as(user)
      expect(post.visible_to?(user)).not_to eq(true)

      put :update, params: { id: post.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "requires notes from moderators" do
      post = create(:post, privacy: :private)
      login_as(create(:admin_user))
      put :update, params: { id: post.id }
      expect(response).to render_template(:edit)
      expect(flash[:error]).to eq('You must provide a reason for your moderator edit.')
    end

    it "does not require note from coauthors" do
      post = create(:post, privacy: :access_list)
      user = create(:user)
      post.viewers << user
      post.authors << user
      login_as(user)
      put :update, params: { id: post.id }
      expect(flash[:success]).not_to be_nil
      expect(flash[:error]).not_to eq('You must provide a reason for your moderator edit.')
    end

    it "stores note from moderators" do
      Post.auditing_enabled = true
      post = create(:post, privacy: :private)
      admin = create(:admin_user)
      login_as(admin)
      put :update, params: {
        id: post.id,
        post: { description: 'b' },
        reply: { audit_comment: 'note' }
      }
      expect(flash[:success]).to eq("Your post has been updated.")
      expect(post.reload.description).to eq('b')
      expect(post.audits.last.comment).to eq('note')
      Post.auditing_enabled = false
    end

    context "mark unread" do
      # rubocop:disable RSpec/RepeatedExample
      it "requires valid at_id" do
        skip "TODO does not notify"
      end

      it "requires post's at_id" do
        skip "TODO does not notify"
      end
      # rubocop:enable RSpec/RepeatedExample

      it "works with at_id" do
        post = create(:post)
        unread_reply = build(:reply, post: post)
        Timecop.freeze(post.created_at + 1.minute) do
          unread_reply.save!
          create(:reply, post: post)
        end
        Timecop.freeze(post.created_at + 2.minutes) do
          post.mark_read(post.user)
        end
        expect(post.last_read(post.user)).to be_the_same_time_as(post.created_at + 2.minutes)
        login_as(post.user)

        put :update, params: { id: post.id, unread: true, at_id: unread_reply.id }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("Post has been marked as read until reply ##{unread_reply.id}.")
        expect(post.reload.last_read(post.user)).to be_the_same_time_as((unread_reply.created_at - 1.second))
        expect(post.reload.first_unread_for(post.user)).to eq(unread_reply)
      end

      it "works without at_id" do
        post = create(:post)
        user = create(:user)
        post.mark_read(user)
        expect(post.reload.send(:view_for, user)).not_to be_nil
        login_as(user)

        put :update, params: { id: post.id, unread: true }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("Post has been marked as unread")
        expect(post.reload.first_unread_for(user)).to eq(post)
      end

      it "works when ignored with at_id" do
        user = create(:user)
        post = create(:post)
        unread_reply = build(:reply, post: post)
        Timecop.freeze(post.created_at + 1.minute) do
          unread_reply.save!
          create(:reply, post: post)
        end
        Timecop.freeze(post.created_at + 2.minutes) do
          post.mark_read(user)
          post.ignore(user)
        end
        expect(post.reload.first_unread_for(user)).to be_nil
        login_as(user)

        put :update, params: { id: post.id, unread: true, at_id: unread_reply.id }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("Post has been marked as read until reply ##{unread_reply.id}.")
        expect(post.reload.last_read(user)).to be_the_same_time_as((unread_reply.created_at - 1.second))
        expect(post.reload.first_unread_for(user)).to eq(unread_reply)
        expect(post).to be_ignored_by(user)
      end

      it "works when ignored without at_id" do
        post = create(:post)
        user = create(:user)
        post.mark_read(user)
        post.ignore(user)
        expect(post.reload.first_unread_for(user)).to be_nil
        login_as(user)

        put :update, params: { id: post.id, unread: true }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("Post has been marked as unread")
        expect(post.reload.first_unread_for(user)).to eq(post)
      end
    end

    context "change status" do
      it "requires permission" do
        post = create(:post)
        login
        put :update, params: { id: post.id, status: 'complete' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("You do not have permission to modify this post.")
        expect(post.reload).to be_active
      end

      it "requires valid status" do
        post = create(:post)
        login_as(post.user)
        put :update, params: { id: post.id, status: 'invalid' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("Invalid status selected.")
        expect(post.reload).to be_active
      end

      it "handles unexpected failure" do
        post = create(:post, status: :active)
        login_as(post.user)
        post.update_columns(board_id: 0) # rubocop:disable Rails/SkipsModelValidations
        expect(post.reload).not_to be_valid
        put :update, params: { id: post.id, status: 'abandoned' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error][:message]).to eq('Status could not be updated.')
        expect(post.reload.status).not_to eq(:abandoned)
      end

      it "marks read after completed" do
        post = nil
        Timecop.freeze(Time.zone.now - 1.day) do
          post = create(:post)
          login_as(post.user)
          post.mark_read(post.user)
        end
        put :update, params: { id: post.id, status: 'complete' }
        post = Post.find(post.id)
        expect(post.last_read(post.user)).to be_the_same_time_as(post.tagged_at)
      end

      Post.statuses.each_key do |status|
        context "to #{status}" do
          let(:post) { create(:post) }

          it "works for creator" do
            login_as(post.user)
            put :update, params: { id: post.id, status: status }
            expect(response).to redirect_to(post_url(post))
            expect(flash[:success]).to eq("Post has been marked #{status}.")
            expect(post.reload.send("#{status}?")).to eq(true)
          end

          it "works for coauthor" do
            reply = create(:reply, post: post)
            login_as(reply.user)
            put :update, params: { id: post.id, status: status }
            expect(response).to redirect_to(post_url(post))
            expect(flash[:success]).to eq("Post has been marked #{status}.")
            expect(post.reload.send("#{status}?")).to eq(true)
          end

          it "works for admin" do
            login_as(create(:admin_user))
            put :update, params: { id: post.id, status: status }
            expect(response).to redirect_to(post_url(post))
            expect(flash[:success]).to eq("Post has been marked #{status}.")
            expect(post.reload.send("#{status}?")).to eq(true)
          end
        end
      end

      context "with an old thread" do
        [:hiatus, :active].each do |status|
          context "to #{status}" do
            time = 2.months.ago
            let(:post) { create(:post, created_at: time, updated_at: time) }
            let(:reply) { create(:reply, post: post, created_at: time, updated_at: time) }

            before (:each) { reply }

            it "works for creator" do
              login_as(post.user)
              expect(post.reload.tagged_at).to be_the_same_time_as(time)
              put :update, params: { id: post.id, status: status }
              expect(response).to redirect_to(post_url(post))
              expect(flash[:success]).to eq("Post has been marked #{status}.")
              expect(post.reload.send("on_hiatus?")).to eq(true)
              expect(post.reload.send("hiatus?")).to eq(status == :hiatus)
            end

            it "works for coauthor" do
              login_as(reply.user)
              expect(post.reload.tagged_at).to be_the_same_time_as(time)
              put :update, params: { id: post.id, status: status }
              expect(response).to redirect_to(post_url(post))
              expect(flash[:success]).to eq("Post has been marked #{status}.")
              expect(post.reload.send("on_hiatus?")).to eq(true)
              expect(post.reload.send("hiatus?")).to eq(status == :hiatus)
            end

            it "works for admin" do
              login_as(create(:admin_user))
              expect(post.reload.tagged_at).to be_the_same_time_as(time)
              put :update, params: { id: post.id, status: status }
              expect(response).to redirect_to(post_url(post))
              expect(flash[:success]).to eq("Post has been marked #{status}.")
              expect(post.reload.send("on_hiatus?")).to eq(true)
              expect(post.reload.send("hiatus?")).to eq(status == :hiatus)
            end
          end
        end
      end
    end

    context "author lock" do
      let(:post) { create(:post, authors_locked: false) }

      it "requires permission" do
        login
        put :update, params: { id: post.id, authors_locked: 'true' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("You do not have permission to modify this post.")
        expect(post.reload).not_to be_authors_locked
      end

      it "works for creator" do
        login_as(post.user)
        put :update, params: { id: post.id, authors_locked: 'true' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been locked to current authors.")
        expect(post.reload).to be_authors_locked

        put :update, params: { id: post.id, authors_locked: 'false' }
        expect(flash[:success]).to eq("Post has been unlocked from current authors.")
        expect(post.reload).not_to be_authors_locked
      end

      it "works for coauthor" do
        reply = create(:reply, post: post)
        login_as(reply.user)
        put :update, params: { id: post.id, authors_locked: 'true' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been locked to current authors.")
        expect(post.reload).to be_authors_locked

        put :update, params: { id: post.id, authors_locked: 'false' }
        expect(flash[:success]).to eq("Post has been unlocked from current authors.")
        expect(post.reload).not_to be_authors_locked
      end

      it "works for admin" do
        login_as(create(:admin_user))
        put :update, params: { id: post.id, authors_locked: 'true' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been locked to current authors.")
        expect(post.reload).to be_authors_locked

        put :update, params: { id: post.id, authors_locked: 'false' }
        expect(flash[:success]).to eq("Post has been unlocked from current authors.")
        expect(post.reload).not_to be_authors_locked
      end

      it "handles unexpected failure" do
        post = create(:post)
        login_as(post.user)
        post.update_columns(board_id: 0) # rubocop:disable Rails/SkipsModelValidations
        expect(post.reload).not_to be_valid
        put :update, params: { id: post.id, authors_locked: 'true' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error][:message]).to eq('Post could not be updated.')
        expect(post.reload).not_to be_authors_locked
      end
    end

    context "mark hidden" do
      it "marks hidden" do
        post = create(:post)
        reply = create(:reply, post: post)
        user = create(:user)
        post.mark_read(user, at_time: post.read_time_for([reply]))
        time_read = post.reload.last_read(user)

        login_as(user)
        expect(post.ignored_by?(user)).not_to eq(true)

        put :update, params: { id: post.id, hidden: 'true' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been hidden")
        expect(post.reload.ignored_by?(user)).to eq(true)
        expect(post.last_read(user)).to be_the_same_time_as(time_read)
      end

      it "marks unhidden" do
        post = create(:post)
        reply = create(:reply, post: post)
        user = create(:user)
        login_as(user)
        post.mark_read(user, at_time: post.read_time_for([reply]))
        time_read = post.reload.last_read(user)

        post.ignore(user)
        expect(post.reload.ignored_by?(user)).to eq(true)

        put :update, params: { id: post.id, hidden: 'false' }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Post has been unhidden")
        expect(post.reload.ignored_by?(user)).not_to eq(true)
        expect(post.last_read(user)).to be_the_same_time_as(time_read)
      end
    end

    context "preview" do
      it "handles tags appropriately in memory and storage" do
        user = create(:user)
        login_as(user)

        setting = create(:setting)
        rems = create(:setting)
        dupes = create(:setting, name: 'dupesetting')
        warning = create(:content_warning)
        remw = create(:content_warning)
        dupew = create(:content_warning, name: 'dupewarning')
        label = create(:label)
        reml = create(:label)
        dupel = create(:label, name: 'dupelabel')

        post = create(:post, user: user, settings: [setting, rems], content_warnings: [warning, remw], labels: [label, reml])
        expect(Setting.count).to eq(3)
        expect(ContentWarning.count).to eq(3)
        expect(Label.count).to eq(3)
        expect(PostTag.count).to eq(6)

        # for each type: keep one, remove one, create one, existing one
        setting_ids = [setting.id, '_setting', '_dupesetting']
        warning_ids = [warning.id, '_warning', '_dupewarning']
        label_ids = [label.id, '_label', '_dupelabel']
        put :update, params: {
          id: post.id,
          button_preview: true,
          post: {
            setting_ids: setting_ids,
            content_warning_ids: warning_ids,
            label_ids: label_ids
          }
        }
        expect(response).to render_template(:preview)
        post = assigns(:post)

        expect(post.settings.size).to eq(2)
        expect(post.content_warnings.size).to eq(2)
        expect(post.labels.size).to eq(2)
        expect(assigns(:settings).map(&:name)).to match_array([setting.name, 'setting', 'dupesetting'])
        expect(assigns(:content_warnings).map(&:name)).to match_array([warning.name, 'warning', 'dupewarning'])
        expect(assigns(:labels).map(&:name)).to match_array([label.name, 'label', 'dupelabel'])
        expect(Setting.count).to eq(3)
        expect(ContentWarning.count).to eq(3)
        expect(Label.count).to eq(3)
        expect(PostTag.count).to eq(6)
        expect(PostTag.where(post: post, tag: [setting, warning, label]).count).to eq(3)
        expect(PostTag.where(post: post, tag: [dupes, dupew, dupel]).count).to eq(0)
        expect(PostTag.where(post: post, tag: [reml, remw, rems]).count).to eq(3)
      end

      it "sets expected variables" do
        Post.auditing_enabled = true
        user = create(:user)
        login_as(user)
        post = create(:post, user: user, subject: 'old', content: 'example')
        setting1 = create(:setting)
        setting2 = create(:setting)
        warning1 = create(:content_warning)
        warning2 = create(:content_warning)
        label1 = create(:label)
        label2 = create(:label)
        char1 = create(:character, user: user)
        char2 = create(:template_character, user: user)
        icon = create(:icon, user: user)
        calias = create(:alias, character: char1)
        coauthor = create(:user)
        viewer = create(:user)
        expect(controller).to receive(:editor_setup).and_call_original
        expect(controller).to receive(:setup_layout_gon).and_call_original
        put :update, params: {
          id: post.id,
          button_preview: true,
          post: {
            subject: 'test',
            setting_ids: [setting1.id, '_'+setting2.name, '_other'],
            content_warning_ids: [warning1.id, '_'+warning2.name, '_other'],
            label_ids: [label1.id, '_'+label2.name, '_other'],
            unjoined_author_ids: [coauthor.id],
            viewer_ids: [viewer.id]
          },
          reply: {
            content: 'orign',
            character_id: char1.id,
            icon_id: icon.id,
            character_alias_id: calias.id
          }
        }
        expect(response).to render_template(:preview)
        expect(assigns(:post).written).to be_an_instance_of(Reply)
        expect(assigns(:post).written).not_to be_a_new_record
        expect(assigns(:post).user).to eq(user)
        expect(assigns(:post).subject).to eq('test')
        expect(assigns(:post).written.content).to eq('orign')
        expect(assigns(:post).written.character).to eq(char1)
        expect(assigns(:post).written.icon).to eq(icon)
        expect(assigns(:post).written.character_alias).to eq(calias)
        expect(assigns(:page_title)).to eq('Previewing: test')
        expect(assigns(:audits)).to eq({post: 1})

        # editor_setup:
        expect(assigns(:javascripts)).to include('posts/editor')
        expect(controller.gon.editor_user[:username]).to eq(user.username)
        expect(assigns(:author_ids)).to match_array([coauthor.id])
        # ensure it doesn't change the actual post:
        expect(post.reload.tagging_authors).to match_array([user])
        expect(post.viewer_ids).to be_empty
        expect(assigns(:viewer_ids)).to eq([viewer.id.to_s])

        # templates
        templates = assigns(:templates)
        expect(templates.length).to eq(3)
        thread_chars = templates.first
        expect(thread_chars.name).to eq('Thread characters')
        expect(thread_chars.plucked_characters).to eq([[char1.id, char1.name]])
        template_chars = templates[1]
        expect(template_chars).to eq(char2.template)
        templateless = templates.last
        expect(templateless.name).to eq('Templateless')
        expect(templateless.plucked_characters).to eq([[char1.id, char1.name]])

        # tags
        expect(assigns(:post).settings.size).to eq(0)
        expect(assigns(:post).content_warnings.size).to eq(0)
        expect(assigns(:post).labels.size).to eq(0)
        expect(assigns(:settings).map(&:id_for_select)).to match_array([setting1.id, setting2.id, '_other'])
        expect(assigns(:content_warnings).map(&:id_for_select)).to match_array([warning1.id, warning2.id, '_other'])
        expect(assigns(:labels).map(&:id_for_select)).to match_array([label1.id, label2.id, '_other'])
        expect(Setting.count).to eq(2)
        expect(ContentWarning.count).to eq(2)
        expect(Label.count).to eq(2)
        expect(PostTag.count).to eq(0)

        # in storage
        post = assigns(:post).reload
        expect(post.user).to eq(user)
        expect(post.subject).to eq('old')
        expect(post.written.content).to eq('example')
        expect(post.written.character).to be_nil
        expect(post.written.icon).to be_nil
        expect(post.written.character_alias).to be_nil
        Post.auditing_enabled = false
      end

      it "does not crash without arguments" do
        user = create(:user)
        login_as(user)
        post = create(:post, user: user)
        put :update, params: { id: post.id, button_preview: true }
        expect(response).to render_template(:preview)
        expect(assigns(:post).written.user).to eq(user)
      end

      it "saves a draft" do
        skip "TODO"
      end

      it "does not create authors or viewers" do
        user = create(:user)
        login_as(user)

        coauthor = create(:user)
        board = create(:board, creator: user, authors_locked: true)
        post = create(:post, user: user, board: board, authors_locked: true, privacy: :access_list)

        expect {
          put :update, params: {
            id: post.id,
            button_preview: true,
            post: {
              unjoined_author_ids: [coauthor.id],
              viewer_ids: [coauthor.id, create(:user).id],
            },
          }
        }.not_to change { [Post::Author.count, PostViewer.count, BoardAuthor.count] }

        expect(flash[:error]).to be_nil
        expect(assigns(:page_title)).to eq('Previewing: ' + assigns(:post).subject.to_s)
      end

      skip "TODO"
    end

    context "make changes" do
      it "creates new tags if needed" do
        user = create(:user)
        login_as(user)

        setting = create(:setting)
        rems = create(:setting)
        dupes = create(:setting, name: 'dupesetting')
        warning = create(:content_warning)
        remw = create(:content_warning)
        dupew = create(:content_warning, name: 'dupewarning')
        label = create(:label)
        reml = create(:label)
        dupel = create(:label, name: 'dupelabel')

        post = create(:post, user: user, settings: [setting, rems], content_warnings: [warning, remw], labels: [label, reml])
        expect(Setting.count).to eq(3)
        expect(ContentWarning.count).to eq(3)
        expect(Label.count).to eq(3)
        expect(PostTag.count).to eq(6)

        # for each type: keep one, remove one, create one, existing one
        setting_ids = [setting.id, '_setting', '_dupesetting']
        warning_ids = [warning.id, '_warning', '_dupewarning']
        label_ids = [label.id, '_label', '_dupelabel']
        put :update, params: {
          id: post.id,
          post: {
            setting_ids: setting_ids,
            content_warning_ids: warning_ids,
            label_ids: label_ids
          }
        }
        expect(response).to redirect_to(post_url(post))
        post = assigns(:post)

        expect(post.settings.size).to eq(3)
        expect(post.content_warnings.size).to eq(3)
        expect(post.labels.size).to eq(3)
        expect(post.settings.map(&:name)).to match_array([setting.name, 'setting', 'dupesetting'])
        expect(post.content_warnings.map(&:name)).to match_array([warning.name, 'warning', 'dupewarning'])
        expect(post.labels.map(&:name)).to match_array([label.name, 'label', 'dupelabel'])
        expect(Setting.count).to eq(4)
        expect(ContentWarning.count).to eq(4)
        expect(Label.count).to eq(4)
        expect(PostTag.count).to eq(9)
        expect(PostTag.where(post: post, tag: [setting, warning, label]).count).to eq(3)
        expect(PostTag.where(post: post, tag: [dupes, dupew, dupel]).count).to eq(3)
        expect(PostTag.where(post: post, tag: [reml, remw, rems]).count).to eq(0)
      end

      it "uses extant tags if available" do
        user = create(:user)
        login_as(user)
        post = create(:post, user: user)
        setting_ids = ['_setting']
        setting = create(:setting, name: 'setting')
        warning_ids = ['_warning']
        warning = create(:content_warning, name: 'warning')
        label_ids = ['_label']
        tag = create(:label, name: 'label')
        put :update, params: {
          id: post.id,
          post: {setting_ids: setting_ids, content_warning_ids: warning_ids, label_ids: label_ids}
        }
        expect(response).to redirect_to(post_url(post))
        post = assigns(:post)
        expect(post.settings).to eq([setting])
        expect(post.content_warnings).to eq([warning])
        expect(post.labels).to eq([tag])
      end

      it "correctly updates when adding new authors" do
        user = create(:user)
        other_user = create(:user)
        login_as(user)
        post = create(:post, user: user)

        time = Time.zone.now + 5.minutes
        Timecop.freeze(time) do
          expect {
            put :update, params: {
              id: post.id,
              post: {
                unjoined_author_ids: [other_user.id]
              }
            }
          }.to change { Post::Author.count }.by(1)
        end

        expect(response).to redirect_to(post_url(post))
        post.reload
        expect(post.tagging_authors).to match_array([user, other_user])

        # doesn't change joined time or invited status when inviting main user
        main_author = post.author_for(user)
        expect(main_author.can_owe).to eq(true)
        expect(main_author.joined).to eq(true)
        expect(main_author.joined_at).to be_the_same_time_as(post.created_at)

        # doesn't set joined time but does set invited status when inviting new user
        new_author = post.author_for(other_user)
        expect(new_author.can_owe).to eq(true)
        expect(new_author.joined).to eq(false)
        expect(new_author.joined_at).to be_nil
      end

      it "correctly updates when removing authors" do
        user = create(:user)
        invited_user = create(:user)
        joined_user = create(:user)

        login_as(user)
        time = Time.zone.now - 5.minutes
        post = reply = nil
        Timecop.freeze(time) do
          post = create(:post, user: user, unjoined_authors: [invited_user])
          reply = create(:reply, user: joined_user, post: post)
        end

        post.reload
        expect(post.authors).to match_array([user, invited_user, joined_user])
        expect(post.joined_authors).to match_array([user, joined_user])

        post_author = post.author_for(user)
        expect(post_author.joined).to eq(true)
        expect(post_author.joined_at).to be_the_same_time_as(post.created_at)

        invited_post_author = post.author_for(invited_user)
        expect(invited_post_author.joined).to eq(false)

        joined_post_author = post.author_for(joined_user)
        expect(joined_post_author.joined).to eq(true)
        expect(joined_post_author.joined_at).to be_the_same_time_as(reply.created_at)

        put :update, params: {
          id: post.id,
          post: {
            unjoined_author_ids: ['']
          }
        }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq('Your post has been updated.')

        post.reload
        expect(post.authors).to match_array([user, joined_user])
        expect(post.joined_authors).to match_array([user, joined_user])
        expect(post.tagging_authors).to match_array([user, joined_user])

        post_author.reload
        expect(post_author.can_owe).to eq(true)
        expect(post_author.joined).to eq(true)
        expect(post_author.joined_at).to be_the_same_time_as(post.created_at)

        expect(post.author_for(invited_user)).to be_nil

        joined_post_author.reload
        expect(joined_post_author.can_owe).to eq(true)
        expect(joined_post_author.joined).to eq(true)
        expect(joined_post_author.joined_at).to be_the_same_time_as(reply.created_at)
      end

      it "updates board cameos if necessary" do
        user = create(:user)
        other_user = create(:user)
        third_user = create(:user)
        login_as(user)
        board = create(:board, creator: user, writers: [other_user])
        post = create(:post, user: user, board: board)
        put :update, params: {
          id: post.id,
          post: {
            unjoined_author_ids: [other_user.id, third_user.id]
          }
        }
        post.reload
        board.reload
        expect(post.tagging_authors).to match_array([user, other_user, third_user])
        expect(board.cameos).to match_array([third_user])
      end

      it "does not add to cameos of open boards" do
        user = create(:user)
        other_user = create(:user)
        login_as(user)
        board = create(:board)
        expect(board.cameos).to be_empty
        post = create(:post, user: user, board: board)
        put :update, params: {
          id: post.id,
          post: {
            unjoined_author_ids: [other_user.id]
          }
        }
        post.reload
        board.reload
        expect(post.tagging_authors).to match_array([user, other_user])
        expect(board.cameos).to be_empty
      end

      it "orders tags" do
        user = create(:user)
        login_as(user)
        post = create(:post, user: user)
        setting2 = create(:setting)
        setting3 = create(:setting)
        setting1 = create(:setting)
        warning1 = create(:content_warning)
        warning3 = create(:content_warning)
        warning2 = create(:content_warning)
        tag3 = create(:label)
        tag1 = create(:label)
        tag2 = create(:label)
        put :update, params: {
          id: post.id,
          post: {
            setting_ids: [setting1, setting2, setting3].map(&:id),
            content_warning_ids: [warning1, warning2, warning3].map(&:id),
            label_ids: [tag1, tag2, tag3].map(&:id)
          }
        }
        expect(response).to redirect_to(post_url(post))
        post = assigns(:post)
        expect(post.settings).to eq([setting1, setting2, setting3])
        expect(post.content_warnings).to eq([warning1, warning2, warning3])
        expect(post.labels).to eq([tag1, tag2, tag3])
      end

      it "requires valid update" do
        setting = create(:setting)
        rems = create(:setting)
        dupes = create(:setting, name: 'dupesetting')
        warning = create(:content_warning)
        remw = create(:content_warning)
        dupew = create(:content_warning, name: 'dupewarning')
        label = create(:label)
        reml = create(:label)
        dupel = create(:label, name: 'dupelabel')

        user = create(:user)
        login_as(user)

        post = create(:post, user: user, settings: [setting, rems], content_warnings: [warning, remw], labels: [label, reml])
        expect(Setting.count).to eq(3)
        expect(ContentWarning.count).to eq(3)
        expect(Label.count).to eq(3)
        expect(PostTag.count).to eq(6)

        char1 = create(:character, user: user)
        char2 = create(:template_character, user: user)

        coauthor = create(:user)

        expect(controller).to receive(:editor_setup).and_call_original
        expect(controller).to receive(:setup_layout_gon).and_call_original

        # for each type: keep one, remove one, create one, existing one
        setting_ids = [setting.id, '_setting', '_dupesetting']
        warning_ids = [warning.id, '_warning', '_dupewarning']
        label_ids = [label.id, '_label', '_dupelabel']
        put :update, params: {
          id: post.id,
          post: {
            subject: '',
            setting_ids: setting_ids,
            content_warning_ids: warning_ids,
            label_ids: label_ids,
            unjoined_author_ids: [coauthor.id]
          }
        }

        expect(response).to render_template(:edit)
        expect(flash[:error][:message]).to eq("Your post could not be saved because of the following problems:")
        expect(post.reload.subject).not_to be_empty

        # editor_setup:
        expect(assigns(:javascripts)).to include('posts/editor')
        expect(controller.gon.editor_user[:username]).to eq(user.username)
        expect(assigns(:author_ids)).to match_array([coauthor.id])

        # templates
        templates = assigns(:templates)
        expect(templates.length).to eq(2)
        template_chars = templates.first
        expect(template_chars).to eq(char2.template)
        templateless = templates.last
        expect(templateless.name).to eq('Templateless')
        expect(templateless.plucked_characters).to eq([[char1.id, char1.name]])

        # tags change only in memory when save fails
        post = assigns(:post)
        expect(post.settings.size).to eq(3)
        expect(post.content_warnings.size).to eq(3)
        expect(post.labels.size).to eq(3)
        expect(post.settings.map(&:name)).to match_array([setting.name, 'setting', 'dupesetting'])
        expect(post.content_warnings.map(&:name)).to match_array([warning.name, 'warning', 'dupewarning'])
        expect(post.labels.map(&:name)).to match_array([label.name, 'label', 'dupelabel'])
        expect(Setting.count).to eq(3)
        expect(ContentWarning.count).to eq(3)
        expect(Label.count).to eq(3)
        expect(PostTag.count).to eq(6)
        expect(PostTag.where(post: post, tag: [setting, warning, label]).count).to eq(3)
        expect(PostTag.where(post: post, tag: [dupes, dupew, dupel]).count).to eq(0)
        expect(PostTag.where(post: post, tag: [reml, remw, rems]).count).to eq(3)
      end

      it "works" do
        user = create(:user)
        removed_author = create(:user)
        joined_author = create(:user)

        post = create(:post, user: user, unjoined_authors: [removed_author])
        create(:reply, user: joined_author, post: post)

        newcontent = post.written.content + 'new'
        newsubj = post.subject + 'new'
        login_as(user)
        board = create(:board)
        section = create(:board_section, board: board)
        char = create(:character, user: user)
        calias = create(:alias, character_id: char.id)
        icon = create(:icon, user: user)
        viewer = create(:user)
        setting = create(:setting)
        warning = create(:content_warning)
        tag = create(:label)
        coauthor = create(:user)

        post.reload
        expect(post.tagging_authors).to match_array([user, removed_author, joined_author])
        expect(post.joined_authors).to match_array([user, joined_author])
        expect(post.viewers).to be_empty

        put :update, params: {
          id: post.id,
          post: {
            subject: newsubj,
            description: 'desc',
            board_id: board.id,
            section_id: section.id,
            privacy: :access_list,
            viewer_ids: [viewer.id],
            setting_ids: [setting.id],
            content_warning_ids: [warning.id],
            label_ids: [tag.id],
            unjoined_author_ids: [coauthor.id]
          },
          reply: {
            content: newcontent,
            character_id: char.id,
            character_alias_id: calias.id,
            icon_id: icon.id
          }
        }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Your post has been updated.")

        post.reload
        post.written.reload
        expect(post.written.content).to eq(newcontent)
        expect(post.subject).to eq(newsubj)
        expect(post.description).to eq('desc')
        expect(post.board_id).to eq(board.id)
        expect(post.section_id).to eq(section.id)
        expect(post.written.character_id).to eq(char.id)
        expect(post.written.character_alias_id).to eq(calias.id)
        expect(post.written.icon_id).to eq(icon.id)
        expect(post).to be_privacy_access_list
        expect(post.viewers).to match_array([viewer])
        expect(post.settings).to eq([setting])
        expect(post.content_warnings).to eq([warning])
        expect(post.labels).to eq([tag])
        expect(post.reload).to be_visible_to(viewer)
        expect(post.reload).not_to be_visible_to(create(:user))
        expect(post.tagging_authors).to match_array([user, joined_author, coauthor])
        expect(post.joined_authors).to match_array([user, joined_author])
        expect(post.authors).to match_array([user, coauthor, joined_author])
      end

      it "does not allow coauthors to edit post text" do
        skip "Is not currently implemented on saving data"
        user = create(:user)
        coauthor = create(:user)
        login_as(coauthor)
        post = create(:post, user: user, authors: [user, coauthor], authors_locked: true)
        put :update, params: {
          id: post.id,
          reply: {
            content: "newtext"
          }
        }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("You do not have permission to modify this post.")
      end
    end

    context "metadata" do
      it "allows coauthors" do
        coauthor = create(:user)
        login_as(coauthor)
        post = create(:post, subject: "test subject")
        create(:reply, post: post, user: coauthor)
        put :update, params: {
          id: post.id,
          post: {
            subject: "new subject"
          }
        }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Your post has been updated.")
        post.reload
        expect(post.subject).to eq("new subject")
      end

      it "allows invited coauthors before they reply" do
        user = create(:user)
        coauthor = create(:user)
        login_as(coauthor)
        post = create(:post, user: user, authors: [user, coauthor], authors_locked: true, subject: "test subject")
        put :update, params: {
          id: post.id,
          post: {
            subject: "new subject"
          }
        }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:success]).to eq("Your post has been updated.")
        post.reload
        expect(post.subject).to eq("new subject")
      end

      it "does not allow non-coauthors" do
        login
        post = create(:post, subject: "test subject")
        put :update, params: {
          id: post.id,
          post: {
            subject: "new subject"
          }
        }
        expect(response).to redirect_to(post_url(post))
        expect(flash[:error]).to eq("You do not have permission to modify this post.")
        post.reload
        expect(post.subject).to eq("test subject")
      end
    end

    context "notes" do
      it "updates if there are no other changes" do
        post = create(:post)
        login_as(post.user)
        expect(post.author_for(post.user).private_note).to be_nil
        put :update, params: {
          id: post.id,
          post: {
            private_note: 'look a note!'
          }
        }
        expect(Post.find_by_id(post.id).author_for(post.user).private_note).not_to be_nil
      end

      it "updates with other changes" do
        post = create(:post, content: 'old')
        login_as(post.user)
        expect(post.author_for(post.user).private_note).to be_nil
        put :update, params: {
          id: post.id,
          post: {
            private_note: 'look a note!',
            subject: 'new'
          }
        }
        expect(Post.find_by_id(post.id).author_for(post.user).private_note).not_to be_nil
        expect(post.reload.subject).to eq('new')
      end

      it "updates with written changes" do
        post = create(:post, content: 'old')
        login_as(post.user)
        expect(post.author_for(post.user).private_note).to be_nil
        put :update, params: {
          id: post.id,
          post: {
            private_note: 'look a note!',
          },
          reply: {
            content: 'new'
          }
        }
        expect(Post.find_by_id(post.id).author_for(post.user).private_note).not_to be_nil
        expect(post.written.reload.content).to eq('new')
      end

      it "updates with coauthor" do
        post = create(:post)
        reply = create(:reply, post: post)
        login_as(reply.user)
        expect(post.author_for(reply.user).private_note).to be_nil
        put :update, params: {
          id: post.id,
          post: {
            private_note: 'look a note!'
          }
        }
        expect(Post.find_by_id(post.id).author_for(reply.user).private_note).not_to be_nil
      end
    end

    context "with blocks" do
      let(:user) { create(:user) }
      let(:blocked) { create(:user) }
      let(:blocking) { create(:user) }
      let(:other_user) { create(:user) }
      let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

      before(:each) do
        create(:block, blocking_user: user, blocked_user: blocked, hide_me: :posts)
        create(:block, blocking_user: blocking, blocked_user: user, hide_them: :posts)
        allow(Rails).to receive(:cache).and_return(memory_store)
        Rails.cache.clear
      end

      it "regenerates blocked and hidden posts for poster" do
        post = create(:post, user: user, authors_locked: false, unjoined_authors: [other_user])

        expect(blocking.hidden_posts).to be_empty
        expect(blocked.blocked_posts).to be_empty

        login_as(user)

        put :update, params: {
          id: post.id,
          post: { authors_locked: true }
        }

        expect(Rails.cache.exist?(Block.cache_string_for(blocking.id, 'hidden'))).to be(false)
        expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

        expect(blocking.hidden_posts).to eq([post.id])
        expect(blocked.blocked_posts).to eq([post.id])
      end

      it "regenerates blocked and hidden posts for coauthor" do
        post = create(:post, user: other_user, authors_locked: false, unjoined_authors: [user])

        expect(blocking.hidden_posts).to be_empty
        expect(blocked.blocked_posts).to be_empty

        login_as(other_user)

        put :update, params: {
          id: post.id,
          post: { authors_locked: true }
        }

        expect(Rails.cache.exist?(Block.cache_string_for(blocking.id, 'hidden'))).to be(false)
        expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

        expect(blocking.hidden_posts).to eq([post.id])
        expect(blocked.blocked_posts).to eq([post.id])
      end

      it "regenerates blocked and hidden posts for new coauthor" do
        post = create(:post, user: other_user, authors_locked: true)

        expect(blocking.hidden_posts).to be_empty
        expect(blocked.blocked_posts).to be_empty

        login_as(other_user)

        put :update, params: {
          id: post.id,
          post: {
            unjoined_author_ids: [user.id]
          }
        }

        expect(Rails.cache.exist?(Block.cache_string_for(blocking.id, 'hidden'))).to be(false)
        expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

        expect(blocking.hidden_posts).to eq([post.id])
        expect(blocked.blocked_posts).to eq([post.id])
      end

      it "regenerates blocked and hidden posts for removed coauthor" do
        post = create(:post, user: other_user, unjoined_authors: [user], authors_locked: true)

        expect(blocking.hidden_posts).to eq([post.id])
        expect(blocked.blocked_posts).to eq([post.id])

        login_as(other_user)

        put :update, params: {
          id: post.id,
          post: {
            unjoined_author_ids: ['']
          }
        }

        post.reload
        expect(post.unjoined_authors).to be_empty

        expect(Rails.cache.exist?(Block.cache_string_for(blocking.id, 'hidden'))).to be(false)
        expect(Rails.cache.exist?(Block.cache_string_for(blocked.id, 'blocked'))).to be(false)

        expect(blocking.hidden_posts).to be_empty
        expect(blocked.blocked_posts).to be_empty
      end
    end
  end

  describe "POST warnings" do
    it "requires a valid post" do
      post :warnings, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires permission" do
      warn_post = create(:post, privacy: :private)
      post :warnings, params: { id: warn_post.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "works for logged out" do
      warn_post = create(:post)
      expect(session[:ignore_warnings]).to be_nil
      post :warnings, params: { id: warn_post.id, per_page: 10, page: 2 }
      expect(response).to redirect_to(post_url(warn_post, per_page: 10, page: 2))
      expect(flash[:success]).to eq("All content warnings have been hidden. Proceed at your own risk.")
      expect(session[:ignore_warnings]).to eq(true)
    end

    it "works for logged in" do
      warn_post = create(:post)
      user = create(:user)
      expect(session[:ignore_warnings]).to be_nil
      expect(warn_post.send(:view_for, user)).to be_a_new_record
      login_as(user)
      post :warnings, params: { id: warn_post.id }
      expect(response).to redirect_to(post_url(warn_post))
      expect(flash[:success]).to start_with("Content warnings have been hidden for this thread. Proceed at your own risk.")
      expect(session[:ignore_warnings]).to be_nil
      view = warn_post.reload.send(:view_for, user)
      expect(view).not_to be_a_new_record
      expect(view.warnings_hidden).to eq(true)
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid post" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post permission" do
      user = create(:user)
      login_as(user)
      post = create(:post)
      expect(post).not_to be_editable_by(user)
      delete :destroy, params: { id: post.id }
      expect(response).to redirect_to(post_url(post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "succeeds" do
      post = create(:post)
      login_as(post.user)
      delete :destroy, params: { id: post.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:success]).to eq("Post deleted.")
    end

    it "deletes Post::Authors" do
      user = create(:user)
      login_as(user)
      other_user = create(:user)
      post = create(:post, user: user, authors: [user, other_user])
      id1 = post.post_authors[0].id
      id2 = post.post_authors[1].id
      delete :destroy, params: { id: post.id }
      expect(Post::Author.find_by(id: id1)).to be_nil
      expect(Post::Author.find_by(id: id2)).to be_nil
    end

    it "handles destroy failure" do
      post = create(:post)
      reply = create(:reply, user: post.user, post: post)
      login_as(post.user)
      expect_any_instance_of(Post).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: post.id }
      expect(response).to redirect_to(post_url(post))
      expect(flash[:error]).to eq({message: "Post could not be deleted.", array: []})
      expect(reply.reload.post).to eq(post)
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
      expect(assigns(:page_title)).to eq('Replies Owed')
    end

    context "with views" do
      render_views

      def create_owed(user)
        post = create(:post, user: user)
        create(:reply, post: post)
        post.mark_read(user)
      end

      it "succeeds" do
        user = create(:user)
        login_as(user)
        create_owed(user)
        get :owed
        expect(response.status).to eq(200)
        expect(response.body).to include('note_go_strong')
      end

      it "succeeds with dark" do
        user = create(:user, layout: 'starrydark')
        login_as(user)
        create_owed(user)
        get :owed
        expect(response.status).to eq(200)
        expect(response.body).to include('bullet_go_strong')
      end
    end

    context "with hidden" do
      let(:user) { create(:user) }
      let(:unhidden_post) { create(:post, user: user) }
      let(:hidden_post) { create(:post, user: user) }

      before(:each) do
        login_as(user)
        create(:reply, post: unhidden_post)
        create(:reply, post: hidden_post)
        author = hidden_post.post_authors.where(user_id: user.id).first
        author.update!(can_owe: false)
      end

      it "does not show hidden without arg" do
        get :owed
        expect(assigns(:posts)).to eq([unhidden_post])
      end

      it "shows only hidden with arg" do
        get :owed, params: {view: 'hidden'}
        expect(assigns(:posts)).to eq([hidden_post])
      end
    end

    context "with hiatused" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      before(:each) {
        login_as(user)
        create(:post)
      }

      it "shows hiatused posts" do
        post = create(:post, user: user)
        create(:reply, post: post, user: other_user)
        post.update!(status: :hiatus)

        get :owed, params: {view: 'hiatused'}
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to eq([post])
      end

      it "shows auto-hiatused posts" do
        post = nil
        Timecop.freeze(Time.zone.now - 1.month) do
          post = create(:post, user: user)
          create(:reply, post: post, user: other_user)
        end
        get :owed, params: {view: 'hiatused'}
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to eq([post])
      end
    end

    context "with posts" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:post) { create(:post, user: user) }

      before(:each) do
        other_user
        login_as(user)
      end

      it "shows a post if replied to by someone else" do
        create(:reply, post_id: post.id, user_id: other_user.id)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "hides a post if you reply to it" do
        create(:reply, post_id: post.id, user_id: other_user.id)
        create(:reply, post_id: post.id, user_id: user.id)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "does not show posts from site_testing" do
        site_test = create(:board, id: Board::ID_SITETESTING)

        post.board = site_test
        post.save!
        create(:reply, post_id: post.id, user_id: other_user.id)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "hides completed and abandoned threads" do
        create(:reply, post_id: post.id, user_id: other_user.id)

        post.update!(status: :complete)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty

        post.update!(status: :active)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])

        post.update!(status: :abandoned)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "show hiatused threads by default" do
        create(:reply, post_id: post.id, user_id: other_user.id)
        post.update!(status: :hiatus)

        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "optionally hides hiatused threads" do
        create(:reply, post_id: post.id, user_id: other_user.id)
        post.update!(status: :hiatus)

        user.hide_hiatused_tags_owed = true
        user.save!
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "shows threads the user has been invited to" do
        post = create(:post, user: other_user, unjoined_authors: [user])
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "hides threads the user has manually removed themselves from" do
        post = create(:post, user: other_user, tagging_authors: [other_user])
        create(:reply, post: post, user: user)
        create(:reply, post: post, user: other_user)
        post.opt_out_of_owed(user)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([])
      end

      it "orders posts by tagged_at" do
        post2 = create(:post, user_id: user.id)
        post3 = create(:post, user_id: user.id)
        post1 = create(:post, user_id: user.id)
        create(:reply, post_id: post3.id, user_id: other_user.id)
        create(:reply, post_id: post2.id, user_id: other_user.id)
        create(:reply, post_id: post1.id, user_id: other_user.id)
        get :owed
        expect(assigns(:posts)).to eq([post1, post2, post3])
      end

      it "shows threads with existing drafts" do
        create(:reply, post: post, user: other_user)
        create(:reply, post: post, user: user)
        create(:reply_draft, post: post, user: user)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "does not show threads with drafts by coauthors" do
        create(:reply, post: post, user: other_user)
        create(:reply, post: post, user: user)
        create(:reply_draft, post: post, user: other_user)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to be_empty
      end

      it "shows solo threads" do
        create(:reply, user: user, post: post)
        get :owed
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "does not show top-posts by user" do
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
      expect(assigns(:started)).not_to eq(true)
      expect(assigns(:page_title)).to eq('Unread Threads')
      expect(assigns(:posts)).to be_empty
      expect(assigns(:hide_quicklinks)).to eq(true)
    end

    it "shows appropriate posts" do
      user = create(:user)
      time = Time.zone.now - 10.minutes

      unread_post = create(:post) # post
      opened_post1, opened_post2, read_post1, read_post2, hidden_post = Timecop.freeze(time) do
        opened_post1 = create(:post) # post & reply, read post
        opened_post2 = create(:post) # post & 2 replies, read post & reply
        create(:reply, post: opened_post2) # reply1
        read_post1 = create(:post) # post
        read_post2 = create(:post) # post & reply
        hidden_post = create(:post) # post
        [opened_post1, opened_post2, read_post1, read_post2, hidden_post]
      end
      reply2, reply3 = Timecop.freeze(time + 5.minutes) do
        reply2 = create(:reply, post: opened_post1)
        reply3 = create(:reply, post: opened_post2)
        create(:reply, post: read_post2) # reply 4
        [reply2, reply3]
      end

      opened_post1.mark_read(user, at_time: time)
      opened_post2.mark_read(user, at_time: time)
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
      expect(assigns(:started)).not_to eq(true)
      expect(assigns(:page_title)).to eq('Unread Threads')
      expect(assigns(:posts)).to match_array([unread_post, opened_post1, opened_post2])
      expect(assigns(:hide_quicklinks)).to eq(true)
    end

    it "orders posts by tagged_at" do
      login
      post2 = create(:post)
      post3 = create(:post)
      post1 = create(:post)
      create(:reply, post: post2)
      create(:reply, post: post1)

      get :unread
      expect(assigns(:posts)).to eq([post1, post2, post3])
    end

    it "manages board/post read time mismatches" do
      user = create(:user)

      # no views exist
      unread_post = create(:post)

      # only post view exists
      post_unread_post = create(:post)
      post_unread_post.mark_read(user, at_time: post_unread_post.created_at - 1.second, force: true)
      post_read_post = create(:post)
      post_read_post.mark_read(user)

      # only board view exists
      board_unread_post = create(:post)
      board_unread_post.board.mark_read(user, at_time: board_unread_post.created_at - 1.second, force: true)
      board_read_post = create(:post)
      board_read_post.board.mark_read(user)

      # both exist
      both_unread_post = create(:post)
      both_unread_post.mark_read(user, at_time: both_unread_post.created_at - 1.second, force: true)
      both_unread_post.board.mark_read(user, at_time: both_unread_post.created_at - 1.second, force: true)
      both_board_read_post = create(:post)
      both_board_read_post.mark_read(user, at_time: both_unread_post.created_at - 1.second, force: true)
      both_board_read_post.board.mark_read(user)
      both_post_read_post = create(:post)
      both_post_read_post.board.mark_read(user, at_time: both_unread_post.created_at - 1.second, force: true)
      both_post_read_post.mark_read(user)
      both_read_post = create(:post)
      both_read_post.mark_read(user)
      both_read_post.board.mark_read(user)

      # board ignored
      board_ignored = create(:post)
      board_ignored.mark_read(user, at_time: both_unread_post.created_at - 1.second, force: true)
      board_ignored.board.ignore(user)

      login_as(user)
      get :unread
      expect(assigns(:posts)).to match_array([unread_post, post_unread_post, board_unread_post, both_unread_post, both_board_read_post])
    end

    context "opened" do
      it "accepts parameter to force opened mode" do
        user = create(:user)
        expect(user.unread_opened).not_to eq(true)
        login_as(user)
        get :unread, params: { started: 'true' }
        expect(response).to have_http_status(200)
        expect(assigns(:started)).to eq(true)
        expect(assigns(:page_title)).to eq('Opened Threads')
      end

      it "shows appropriate posts" do
        user = create(:user, unread_opened: true)
        time = Time.zone.now - 10.minutes

        unread_post = create(:post) # post
        opened_post1, opened_post2, read_post1, read_post2, hidden_post = Timecop.freeze(time) do
          opened_post1 = create(:post) # post & reply, read post
          opened_post2 = create(:post) # post & 2 replies, read post & reply
          create(:reply, post: opened_post2) # reply1
          read_post1 = create(:post) # post
          read_post2 = create(:post) # post & reply
          hidden_post = create(:post) # post & reply
          [opened_post1, opened_post2, read_post1, read_post2, hidden_post]
        end
        reply2, reply3 = Timecop.freeze(time + 5.minutes) do
          reply2 = create(:reply, post: opened_post1)
          reply3 = create(:reply, post: opened_post2)
          create(:reply, post: read_post2) # reply4
          create(:reply, post: hidden_post) # reply5
          [reply2, reply3]
        end

        opened_post1.mark_read(user, at_time: time)
        opened_post2.mark_read(user, at_time: time)
        read_post1.mark_read(user)
        read_post2.mark_read(user)
        hidden_post.mark_read(user, at_time: time)
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
        expect(assigns(:started)).to eq(true)
        expect(assigns(:page_title)).to eq('Opened Threads')
        expect(assigns(:posts)).to match_array([opened_post1, opened_post2])
        expect(assigns(:hide_quicklinks)).to eq(true)
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
        private_post = create(:post, privacy: :private)
        user = create(:user)
        expect(private_post.visible_to?(user)).not_to eq(true)
        login_as(user)
        post :mark, params: { marked_ids: [private_post.id], commit: "Mark Read" }
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

        post :mark, params: { marked_ids: [post1.id.to_s, post2.id.to_s], commit: "Mark Read" }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("2 posts marked as read.")
        expect(post1.reload.last_read(user)).not_to be_nil
        expect(post2.reload.last_read(user)).not_to be_nil
      end
    end

    context "ignored" do
      it "skips invisible post" do
        private_post = create(:post, privacy: :private)
        user = create(:user)
        expect(private_post.visible_to?(user)).not_to eq(true)
        login_as(user)
        post :mark, params: { marked_ids: [private_post.id] }
        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("0 posts hidden from this page.")
        expect(private_post.reload.ignored_by?(user)).not_to eq(true)
      end

      it "ignores posts" do
        user = create(:user)
        post1 = create(:post)
        post2 = create(:post)
        login_as(user)

        expect(post1.visible_to?(user)).to eq(true)
        expect(post2.visible_to?(user)).to eq(true)

        post :mark, params: { marked_ids: [post1.id.to_s, post2.id.to_s] }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("2 posts hidden from this page.")
        expect(post1.reload.ignored_by?(user)).to eq(true)
        expect(post2.reload.ignored_by?(user)).to eq(true)
      end

      it "does not mess with read timestamps" do
        user = create(:user)

        time = Time.zone.now - 10.minutes
        post1 = create(:post, created_at: time, updated_at: time) # unread
        post2 = create(:post, created_at: time, updated_at: time) # partially read
        post3 = create(:post, created_at: time, updated_at: time) # fully read
        Array.new(5) { |i| create(:reply, post: post1, created_at: time + i.minutes, updated_at: time + i.minutes) } # replies1
        replies2 = Array.new(5) { |i| create(:reply, post: post2, created_at: time + i.minutes, updated_at: time + i.minutes) }
        replies3 = Array.new(5) { |i| create(:reply, post: post3, created_at: time + i.minutes, updated_at: time + i.minutes) }

        login_as(user)
        expect(post1).to be_visible_to(user)
        expect(post2).to be_visible_to(user)
        expect(post3).to be_visible_to(user)

        time2 = replies2.first.updated_at
        time3 = replies3.last.updated_at
        post2.mark_read(user, at_time: time2)
        post3.mark_read(user, at_time: time3)

        expect(post1.reload.last_read(user)).to be_nil
        expect(post2.reload.last_read(user)).to be_the_same_time_as(time2)
        expect(post3.reload.last_read(user)).to be_the_same_time_as(time3)

        post :mark, params: { marked_ids: [post1, post2, post3].map(&:id).map(&:to_s) }

        expect(response).to redirect_to(unread_posts_url)
        expect(flash[:success]).to eq("3 posts hidden from this page.")
        expect(post1.reload.last_read(user)).to be_nil
        expect(post2.reload.last_read(user)).to be_the_same_time_as(time2)
        expect(post3.reload.last_read(user)).to be_the_same_time_as(time3)
      end
    end

    context "not owed" do
      it "ignores invisible posts" do
        user = create(:user)
        private_post = create(:post, privacy: :private, authors: [user])
        expect(private_post.visible_to?(user)).not_to eq(true)
        expect(private_post.post_authors.find_by(user: user).can_owe).to eq(true)
        login_as(user)
        post :mark, params: { marked_ids: [private_post.id], commit: 'Remove from Replies Owed' }
        expect(response).to redirect_to(owed_posts_url)
        expect(flash[:success]).to eq("0 posts removed from replies owed.")
        expect(private_post.post_authors.find_by(user: user).can_owe).to eq(true)
      end

      it "deletes post author if the user has not yet joined" do
        user = create(:user)
        owed_post = create(:post, unjoined_authors: [user])
        expect(owed_post.post_authors.find_by(user: user).can_owe).to eq(true)
        login_as(user)
        post :mark, params: { marked_ids: [owed_post.id], commit: 'Remove from Replies Owed' }
        expect(response).to redirect_to(owed_posts_url)
        expect(flash[:success]).to eq("1 post removed from replies owed.")
        expect(owed_post.post_authors.find_by(user: user)).to be_nil
      end

      it "updates post author if the user has joined" do
        user = create(:user)
        owed_post = create(:post, unjoined_authors: [user])
        create(:reply, post: owed_post, user: user)
        expect(owed_post.post_authors.find_by(user: user).can_owe).to eq(true)
        expect(owed_post.post_authors.find_by(user: user).joined).to eq(true)
        login_as(user)
        post :mark, params: { marked_ids: [owed_post.id], commit: 'Remove from Replies Owed' }
        expect(response).to redirect_to(owed_posts_url)
        expect(flash[:success]).to eq("1 post removed from replies owed.")
        expect(owed_post.post_authors.find_by(user: user).can_owe).to eq(false)
      end
    end

    context "newly owed" do
      it "ignores invisible posts" do
        user = create(:user)
        private_post = create(:post, privacy: :private, authors: [user])
        expect(private_post.visible_to?(user)).not_to eq(true)
        private_post.author_for(user).update!(can_owe: false)
        login_as(user)
        post :mark, params: { marked_ids: [private_post.id], commit: 'Show in Replies Owed' }
        expect(response).to redirect_to(owed_posts_url)
        expect(flash[:success]).to eq("0 posts added to replies owed.")
        expect(private_post.post_authors.find_by(user: user).can_owe).to eq(false)
      end

      it "does nothing if the user has not yet joined" do
        user = create(:user)
        owed_post = create(:post, unjoined_authors: [user])
        owed_post.opt_out_of_owed(user)
        expect(owed_post.author_for(user)).to be_nil
        login_as(user)
        post :mark, params: { marked_ids: [owed_post.id], commit: 'Show in Replies Owed' }
        expect(response).to redirect_to(owed_posts_url)
        expect(flash[:success]).to eq("1 post added to replies owed.")
        expect(owed_post.post_authors.find_by(user: user)).to be_nil
      end

      it "updates post author if the user has joined" do
        user = create(:user)
        owed_post = create(:post, unjoined_authors: [user])
        create(:reply, post: owed_post, user: user)
        expect(owed_post.post_authors.find_by(user: user).joined).to eq(true)
        owed_post.opt_out_of_owed(user)
        expect(owed_post.post_authors.find_by(user: user).can_owe).to eq(false)
        login_as(user)
        post :mark, params: { marked_ids: [owed_post.id], commit: 'Show in Replies Owed' }
        expect(response).to redirect_to(owed_posts_url)
        expect(flash[:success]).to eq("1 post added to replies owed.")
        expect(owed_post.post_authors.find_by(user: user).can_owe).to eq(true)
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
      post :unhide, params: { unhide_posts: [hidden_post.id] }
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
      post :unhide, params: { unhide_boards: [board.id] }
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

      post :unhide, params: { unhide_boards: [board.id], unhide_posts: [hidden_post.id] }

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

  shared_examples "logged out post list" do
    it "does not show user-only posts" do
      posts = create_list(:post, 2)
      create_list(:post, 2, privacy: :registered)
      get controller_action, params: params
      expect(response.status).to eq(200)
      expect(Post.all.count).to eq(4)
      expect(assigns(assign_variable)).to match_array(posts)
    end
  end

  shared_examples "logged in post list" do
    let(:user) { create(:user) }
    let(:posts) { create_list(:post, 3) }

    before(:each) {
      login_as(user)
      posts
    }

    it "does not show access-locked or private threads" do
      create(:post, privacy: :private)
      create(:post, privacy: :access_list)
      get controller_action, params: params
      expect(response.status).to eq(200)
      expect(assigns(assign_variable)).to match_array(posts)
    end

    it "shows access-locked and private threads if you have access" do
      posts << create(:post, user: user, privacy: :private)
      posts << create(:post, user: user, privacy: :access_list)
      get controller_action, params: params
      expect(response.status).to eq(200)
      expect(assigns(assign_variable)).to match_array(posts)
    end

    it "does not show posts with blocked or blocking authors" do
      post1 = create(:post, authors_locked: true)
      post2 = create(:post, authors_locked: true)
      create(:block, blocking_user: user, blocked_user: post1.user, hide_them: :posts)
      create(:block, blocking_user: post2.user, blocked_user: user, hide_me: :posts)
      get controller_action, params: params
      expect(response.status).to eq(200)
      expect(assigns(assign_variable)).to match_array(posts)
    end

    it "shows posts with a blocked (but not blocking) author with show_blocked" do
      post1 = create(:post, authors_locked: true)
      post2 = create(:post, authors_locked: true)
      create(:block, blocking_user: user, blocked_user: post1.user, hide_them: :posts)
      create(:block, blocking_user: post2.user, blocked_user: user, hide_me: :posts)
      params[:show_blocked] = true
      posts << post1
      get controller_action, params: params
      expect(response.status).to eq(200)
      expect(assigns(assign_variable)).to match_array(posts)
    end

    it "shows your own posts with blocked or but not blocking authors" do
      post1 = create(:post, authors_locked: true, author_ids: [user.id])
      create(:reply, post: post1, user: user)
      post2 = create(:post, authors_locked: true, author_ids: [user.id])
      create(:reply, post: post2, user: user)
      create(:block, blocking_user: user, blocked_user: post1.user, hide_them: :posts)
      create(:block, blocking_user: post2.user, blocked_user: user, hide_me: :posts)
      posts << post2
      get controller_action, params: params
      expect(response.status).to eq(200)
      expect(assigns(assign_variable)).to match_array(posts)
    end
  end

  context "GET index" do
    let(:controller_action) { "index" }
    let(:params) { { } }
    let(:assign_variable) { :posts }

    context "when logged out" do
      include_examples "logged out post list"
    end
    context "when logged in" do
      include_examples "logged in post list"
    end
  end

  context "GET unread" do
    let(:controller_action) { "unread" }
    let(:params) { { } }
    let(:assign_variable) { :posts }

    context "when logged in" do
      include_examples "logged in post list"
    end
  end

  context "GET search" do
    let(:controller_action) { "search" }
    let(:params) { { commit: true } }
    let(:assign_variable) { :search_results }

    context "when logged out" do
      include_examples "logged out post list"
    end
    context "when logged in" do
      include_examples "logged in post list"
    end
  end
end
