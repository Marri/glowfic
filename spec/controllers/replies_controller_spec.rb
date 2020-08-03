RSpec.describe RepliesController do
  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    context "preview" do
      it "takes correct actions" do
        user = create(:user)
        reply_post = create(:post, user: user)
        create(:reply, post: reply_post) # reply
        reply_post.mark_read(user)
        login_as(user)
        expect(ReplyDraft.count).to eq(0)

        char1 = create(:character, user: user)
        icon = create(:icon, user: user)
        calias = create(:alias, character: char1)
        char2 = create(:template_character, user: user)
        expect(controller).to receive(:build_template_groups).and_call_original
        expect(controller).to receive(:make_draft).and_call_original
        expect(controller).to receive(:setup_layout_gon).and_call_original

        post :create, params: {
          button_preview: true,
          reply: {
            content: 'example',
            character_id: char1.id,
            icon_id: icon.id,
            character_alias_id: calias.id,
            post_id: reply_post.id
          }
        }
        expect(response).to render_template(:preview)
        expect(assigns(:javascripts)).to include('posts/editor')
        expect(assigns(:page_title)).to eq(reply_post.subject)
        expect(assigns(:reply)).to be_a_new_record
        expect(assigns(:reply).post).to eq(reply_post)
        expect(assigns(:reply).user).to eq(reply_post.user)
        expect(assigns(:reply).content).to eq('example')
        expect(assigns(:reply).character).to eq(char1)
        expect(assigns(:reply).icon).to eq(icon)
        expect(assigns(:reply).character_alias).to eq(calias)
        expect(assigns(:post)).to eq(reply_post)
        expect(ReplyDraft.count).to eq(1)
        draft = ReplyDraft.last

        expect(draft.post).to eq(reply_post)
        expect(draft.user).to eq(reply_post.user)
        expect(draft.content).to eq('example')
        expect(draft.character).to eq(char1)
        expect(draft.icon).to eq(icon)
        expect(draft.character_alias).to eq(calias)
        expect(flash[:success]).to eq('Draft saved!')

        # build_template_groups:
        expect(controller.gon.editor_user[:username]).to eq(user.username)
        # templates
        templates = assigns(:templates)
        expect(templates.length).to eq(3)
        used = templates.first
        expect(used.name).to eq("Thread characters")
        expect(used.plucked_characters).to eq([[char1.id, char1.name]])
        expect(templates[1]).to eq(char2.template)
        templateless = templates.last
        expect(templateless.name).to eq('Templateless')
        expect(templateless.plucked_characters).to eq([[char1.id, char1.name]])
      end

      it "does not create authors" do
        user = create(:user)
        board = create(:board, authors_locked: true)
        reply_post = create(:post, user: board.creator, board: board)
        expect(reply_post.user.id).not_to eq(user.id)
        login_as(user)

        expect {
          post :create, params: {
            button_preview: true,
            reply: {
              content: 'example',
              post_id: reply_post.id
            }
          }
        }.not_to change { [Post::Author.count, BoardAuthor.count]}

        expect(flash[:success]).to be_present
      end
    end

    context "draft" do
      it "displays errors if relevant" do
        draft = create(:reply_draft)
        login_as(draft.user)
        post :create, params: { button_draft: true, reply: {post_id: ''} }
        expect(flash[:error][:message]).to eq("Your draft could not be saved because of the following problems:")
        expect(draft.reload.post_id).not_to be_nil
        expect(response).to redirect_to(posts_url)
      end

      it "creates a new draft if none exists" do
        user = create(:user)
        reply_post = create(:post, user: user)
        login_as(user)
        char = create(:character, user: user)
        icon = create(:icon, user: user)
        calias = create(:alias, character: char)

        expect(ReplyDraft.count).to eq(0)
        post :create, params: {
          button_draft: true,
          reply: {
            post_id: reply_post.id,
            character_id: char.id,
            icon_id: icon.id,
            content: 'testcontent',
            character_alias_id: calias.id
          }
        }
        expect(response).to redirect_to(post_url(reply_post, page: :unread, anchor: :unread))
        expect(flash[:success]).to eq("Draft saved!")
        expect(ReplyDraft.count).to eq(1)

        draft = ReplyDraft.last
        expect(draft.post).to eq(reply_post)
        expect(draft.user).to eq(user)
        expect(draft.character_id).to eq(char.id)
        expect(draft.icon_id).to eq(icon.id)
        expect(draft.content).to eq('testcontent')
        expect(draft.character_alias_id).to eq(calias.id)
      end

      it "updates the existing draft if one exists" do
        draft = create(:reply_draft)
        login_as(draft.user)
        post :create, params: { button_draft: true, reply: {post_id: draft.post.id, content: 'new draft'} }
        expect(flash[:success]).to eq("Draft saved!")
        expect(draft.reload.content).to eq('new draft')
        expect(ReplyDraft.count).to eq(1)
      end
    end

    it "requires valid post" do
      login
      post :create
      expect(response).to redirect_to(posts_url)
      expect(flash[:error][:message]).to eq("Your reply could not be saved because of the following problems:")
    end

    it "requires post read" do
      reply_post = create(:post)
      login_as(reply_post.user)
      reply_post.mark_read(reply_post.user)
      create(:reply, post: reply_post)

      post :create, params: { reply: {post_id: reply_post.id, user_id: reply_post.user_id} }
      expect(response.status).to eq(200)
      expect(flash[:error]).to eq("There has been 1 new reply since you last viewed this post.")
    end

    it "handles multiple creations with unread warning" do
      reply_post = create(:post)
      login_as(reply_post.user)
      reply_post.mark_read(reply_post.user)
      create(:reply, post: reply_post) # last_seen

      post :create, params: { reply: {post_id: reply_post.id, user_id: reply_post.user_id} }
      expect(response.status).to eq(200)
      expect(flash[:error]).to eq("There has been 1 new reply since you last viewed this post.")

      create(:reply, post: reply_post)
      create(:reply, post: reply_post)

      post :create, params: { reply: {post_id: reply_post.id, user_id: reply_post.user_id} }
      expect(response.status).to eq(200)
      expect(flash[:error]).to eq("There have been 2 new replies since you last viewed this post.")
    end

    it "handles multiple creations by user" do
      reply_post = create(:post)
      login_as(reply_post.user)
      dupe_reply = create(:reply, user: reply_post.user, post: reply_post)
      reply_post.mark_read(reply_post.user, at_time: dupe_reply.created_at + 1.second, force: true)

      post :create, params: { reply: {post_id: reply_post.id, user_id: reply_post.user_id, content: dupe_reply.content} }
      expect(response).to have_http_status(200)
      expect(flash[:error]).to eq("This looks like a duplicate. Did you attempt to post this twice? Please resubmit if this was intentional.")

      post :create, params: { reply: {post_id: reply_post.id, user_id: reply_post.user_id, content: dupe_reply.content}, allow_dupe: true }
      expect(response).to have_http_status(302)
      expect(flash[:success]).to eq("Posted!")
    end

    it "requires valid params if read" do
      user = create(:user)
      login_as(user)
      character = create(:character)
      reply_post = create(:post)
      reply_post.mark_read(user, at_time: reply_post.created_at + 1.second, force: true)

      expect(character.user_id).not_to eq(user.id)
      post :create, params: { reply: {character_id: character.id, post_id: reply_post.id} }
      expect(response).to redirect_to(post_url(reply_post))
      expect(flash[:error][:message]).to eq("Your reply could not be saved because of the following problems:")
    end

    it "saves a new reply successfully if read" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post)
      reply_post.mark_read(user, at_time: reply_post.created_at + 1.second, force: true)
      char = create(:character, user: user)
      icon = create(:icon, user: user)
      calias = create(:alias, character: char)

      expect {
        post :create, params: {
          reply: {
            post_id: reply_post.id,
            content: 'test!',
            character_id: char.id,
            icon_id: icon.id,
            character_alias_id: calias.id
          }
        }
      }.to change{Reply.count}.by(1)

      reply = Reply.order(:id).last
      expect(reply).not_to be_nil
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(flash[:success]).to eq("Posted!")
      expect(reply.user).to eq(user)
      expect(reply.post).to eq(reply_post)
      expect(reply.content).to eq('test!')
      expect(reply.character_id).to eq(char.id)
      expect(reply.icon_id).to eq(icon.id)
      expect(reply.character_alias_id).to eq(calias.id)
    end

    it "allows you to reply to a post you created" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post, user: user)
      reply_post.mark_read(user, at_time: reply_post.created_at + 1.second, force: true)

      expect {
        post :create, params: { reply: {post_id: reply_post.id, content: 'test content!'} }
      }.to change{Reply.count}.by(1)

      reply = Reply.order(:id).last
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(reply).not_to be_nil
      expect(flash[:success]).to eq('Posted!')
      expect(reply.user).to eq(user)
      expect(reply.content).to eq('test content!')
    end

    it "allows you to reply to join a post you did not create" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post)
      reply_post.mark_read(user, at_time: reply_post.created_at + 1.second, force: true)

      expect {
        post :create, params: { reply: {post_id: reply_post.id, content: 'test content again!'} }
      }.to change{Reply.count}.by(1)

      reply = Reply.order(:id).last
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(reply).not_to be_nil
      expect(flash[:success]).to eq('Posted!')
      expect(reply.user).to eq(user)
      expect(reply.content).to eq('test content again!')
    end

    it "allows you to reply to a post you already joined" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post)
      reply_old = create(:reply, post: reply_post, user: user)
      reply_post.mark_read(user, at_time: reply_old.created_at + 1.second, force: true)

      expect {
        post :create, params: { reply: {post_id: reply_post.id, content: 'test content the third!'} }
      }.to change{Reply.count}.by(1)

      reply = Reply.ordered.last
      expect(reply).not_to eq(reply_old)
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(flash[:success]).to eq('Posted!')
      expect(reply.user).to eq(user)
      expect(reply.content).to eq('test content the third!')
    end

    it "allows you to reply to a closed post you already joined" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post)
      reply_old = create(:reply, post: reply_post, user: user)
      reply_post.mark_read(user, at_time: reply_old.created_at + 1.second, force: true)
      reply_post.update!(authors_locked: true)

      expect {
        post :create, params: { reply: {post_id: reply_post.id, content: 'test content the third!'} }
      }.to change{Reply.count}.by(1)

      reply = Reply.order(id: :desc).first
      expect(reply).not_to eq(reply_old)
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(flash[:success]).to eq('Posted!')
      expect(reply.user).to eq(user)
      expect(reply.content).to eq('test content the third!')
    end

    it "allows replies from authors in a closed post" do
      user = create(:user)
      other_user = create(:user)
      login_as(user)
      reply_post = create(:post, user: other_user, tagging_authors: [user, other_user], authors_locked: true)
      reply_post.mark_read(user)
      expect {
        post :create, params: { reply: {post_id: reply_post.id, content: 'test content!'} }
      }.to change{Reply.count}.by(1)
    end

    it "allows replies from owner in a closed post" do
      user = create(:user)
      other_user = create(:user)
      login_as(user)
      other_post = create(:post, user: user, tagging_authors: [user, other_user], authors_locked: true)
      other_post.mark_read(user)
      expect {
        post :create, params: { reply: {post_id: other_post.id, content: 'more test content!'} }
      }.to change{Reply.count}.by(1)
    end

    it "adds authors correctly when a user replies to an open thread" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post)
      reply_post.mark_read(user)

      expect {
        Timecop.freeze(Time.zone.now) do
          post :create, params: { reply: {post_id: reply_post.id, content: 'test content!'} }
        end
      }.to change{Reply.count}.by(1)

      expect(reply_post.tagging_authors).to match_array([user, reply_post.user])
      post_author = reply_post.tagging_post_authors.find_by(user: user)
      expect(post_author.user).to eq(user)
      expect(post_author.joined).to eq(true)
      expect(post_author.joined_at).to be_the_same_time_as(Reply.last.created_at)
      expect(post_author.can_owe).to eq(true)
    end

    it "handles multiple replies to an open thread correctly" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post)
      expect(reply_post.tagging_authors.count).to eq(1)
      old_reply = create(:reply, post: reply_post, user: user)
      reply_post.reload
      expect(reply_post.tagging_authors).to include(user)
      expect(reply_post.tagging_authors.count).to eq(2)
      expect(reply_post.joined_authors).to include(user)
      expect(reply_post.joined_authors.count).to eq(2)
      reply_post.mark_read(user, at_time: old_reply.created_at + 1.second, force: true)
      expect {
        post :create, params: { reply: {post_id: reply_post.id, content: 'test content!'} }
      }.to change{Reply.count}.by(1)
      expect(reply_post.tagging_authors).to match_array([user, reply_post.user])
    end

    it "handles trying to reply to a closed thread as a non-author correctly" do
      user = create(:user)
      login_as(user)
      reply_post = create(:post, authors_locked: true)
      reply_post.mark_read(user)
      post :create, params: { reply: {post_id: reply_post.id, content: 'test'} }
      expect(flash[:error][:message]).to eq("Your reply could not be saved because of the following problems:")
      expect(flash[:error][:array]).to eq(["User #{user.username} cannot write in this post"])
    end

    it "sets reply_order correctly on the first reply" do
      reply_post = create(:post)
      login_as(reply_post.user)
      reply_post.mark_read(reply_post.user)
      searchable = 'searchable content'
      post :create, params: { reply: {post_id: reply_post.id, content: searchable} }
      reply = reply_post.replies.ordered.last
      expect(reply.content).to eq(searchable)
      expect(reply.reply_order).to eq(1)
    end

    it "sets reply_order correctly with an existing reply" do
      reply_post = create(:post)
      login_as(reply_post.user)
      create(:reply, post: reply_post)
      reply_post.mark_read(reply_post.user)
      searchable = 'searchable content'
      post :create, params: { reply: {post_id: reply_post.id, content: searchable} }
      reply = reply_post.replies.ordered.last
      expect(reply.content).to eq(searchable)
      expect(reply.reply_order).to eq(2)
    end

    it "sets reply_order correctly with multiple existing replies" do
      reply_post = create(:post)
      login_as(reply_post.user)
      create(:reply, post: reply_post)
      create(:reply, post: reply_post)
      reply_post.mark_read(reply_post.user)
      searchable = 'searchable content'
      post :create, params: { reply: {post_id: reply_post.id, content: searchable} }
      reply = reply_post.replies.ordered.last
      expect(reply.content).to eq(searchable)
      expect(reply.reply_order).to eq(3)
    end
  end

  describe "GET show" do
    it "requires valid reply" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post access" do
      reply = create(:reply)
      expect(reply.user_id).not_to eq(reply.post.user_id)
      expect(reply.post.visible_to?(reply.user)).to eq(true)

      reply.post.update!(privacy: :private)
      reply.post.save!
      reply.reload
      expect(reply.post.visible_to?(reply.user)).to eq(false)

      login_as(reply.user)
      get :show, params: { id: reply.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "succeeds when logged out" do
      reply = create(:reply)
      get :show, params: { id: reply.id }
      expect(response).to have_http_status(200)
      expect(assigns(:javascripts)).to include('posts/show')
    end

    it "calculates OpenGraph meta" do
      user = create(:user, username: 'user1')
      user2 = create(:user, username: 'user2')
      board = create(:board, name: 'example board')
      section = create(:board_section, board: board, name: 'example section')
      post = create(:post, board: board, section: section, user: user, subject: 'a post', description: 'Test.')
      create_list(:reply, 25, post: post, user: user)
      reply = create(:reply, post: post, user: user2)
      get :show, params: { id: reply.id }
      expect(response).to have_http_status(200)
      expect(assigns(:javascripts)).to include('posts/show')

      meta_og = assigns(:meta_og)
      expect(meta_og[:url]).to eq(post_url(post, page: 2))
      expect(meta_og[:title]).to eq('a post · example board » example section')
      expect(meta_og[:description]).to eq('Test. (user1, user2 – page 2 of 2)')
    end

    it "succeeds when logged in" do
      reply = create(:reply)
      login
      get :show, params: { id: reply.id }
      expect(response).to have_http_status(200)
      expect(assigns(:javascripts)).to include('posts/show')
    end

    it "has more tests" do
      skip
    end
  end

  describe "GET history" do
    it "requires valid reply" do
      get :history, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post access" do
      reply = create(:reply)
      expect(reply.user_id).not_to eq(reply.post.user_id)
      expect(reply.post.visible_to?(reply.user)).to eq(true)

      reply.post.update!(privacy: :private)
      reply.reload
      expect(reply.post.visible_to?(reply.user)).to eq(false)

      login_as(reply.user)
      get :history, params: { id: reply.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "works when logged out" do
      reply = create(:reply)
      get :history, params: { id: reply.id }
      expect(response.status).to eq(200)
    end

    it "works when logged in" do
      reply = create(:reply)
      login
      get :history, params: { id: reply.id }
      expect(response.status).to eq(200)
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid reply" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post access" do
      reply = create(:reply)
      expect(reply.user_id).not_to eq(reply.post.user_id)
      expect(reply.post.visible_to?(reply.user)).to eq(true)

      reply.post.update!(privacy: :private)
      reply.reload
      expect(reply.post.visible_to?(reply.user)).to eq(false)

      login_as(reply.user)
      get :edit, params: { id: reply.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "requires reply access" do
      reply = create(:reply)
      login
      get :edit, params: { id: reply.id }
      expect(response).to redirect_to(post_url(reply.post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "works" do
      user = create(:user)
      reply = create(:reply, user: user)
      login_as(user)
      char1 = create(:character, user: user)
      char2 = create(:template_character, user: user)
      expect(controller).to receive(:build_template_groups).and_call_original
      expect(controller).to receive(:setup_layout_gon).and_call_original

      get :edit, params: { id: reply.id }
      expect(response).to render_template(:edit)
      expect(assigns(:page_title)).to eq(reply.post.subject)
      expect(assigns(:reply)).to eq(reply)
      expect(assigns(:post)).to eq(reply.post)

      # build_template_groups:
      expect(controller.gon.editor_user[:username]).to eq(user.username)
      # templates
      templates = assigns(:templates)
      expect(templates.length).to eq(2)
      template_chars = templates.first
      expect(template_chars).to eq(char2.template)
      templateless = templates.last
      expect(templateless.name).to eq('Templateless')
      expect(templateless.plucked_characters).to eq([[char1.id, char1.name]])
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid reply" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post access" do
      reply = create(:reply)
      expect(reply.user_id).not_to eq(reply.post.user_id)
      expect(reply.post.visible_to?(reply.user)).to eq(true)

      reply.post.update!(privacy: :private)
      reply.post.save!
      reply.reload
      expect(reply.post.visible_to?(reply.user)).to eq(false)

      login_as(reply.user)
      put :update, params: { id: reply.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "requires reply access" do
      reply = create(:reply)
      login
      put :update, params: { id: reply.id }
      expect(response).to redirect_to(post_url(reply.post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "requires notes from moderators" do
      reply = create(:reply)
      login_as(create(:admin_user))
      put :update, params: { id: reply.id }
      expect(response).to render_template(:edit)
      expect(flash[:error]).to eq('You must provide a reason for your moderator edit.')
    end

    it "stores note from moderators" do
      Reply.auditing_enabled = true
      reply = create(:reply, content: 'a')
      admin = create(:admin_user)
      login_as(admin)
      put :update, params: { id: reply.id, reply: { content: 'b', audit_comment: 'note' } }
      expect(flash[:success]).to eq("Post updated")
      expect(reply.reload.content).to eq('b')
      expect(reply.audits.last.comment).to eq('note')
      Reply.auditing_enabled = false
    end

    it "does not save audit when only comment provided" do
      Reply.auditing_enabled = true
      reply = create(:reply)
      login_as(reply.user)
      expect {
        put :update, params: { id: reply.id, reply: { audit_comment: 'note' } }
      }.not_to change { Audited::Audit.count }
      Reply.auditing_enabled = false
    end

    it "fails when invalid" do
      reply = create(:reply)
      login_as(reply.user)
      put :update, params: { id: reply.id, reply: { post_id: nil } }
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Your reply could not be saved because of the following problems:")
    end

    it "succeeds" do
      user = create(:user)
      reply = create(:reply, user: user)
      newcontent = reply.content + 'new'
      login_as(user)
      char = create(:character, user: user)
      icon = create(:icon, user: user)
      calias = create(:alias, character: char)

      put :update, params: { id: reply.id, reply: {content: newcontent, character_id: char.id, icon_id: icon.id, character_alias_id: calias.id} }
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(flash[:success]).to eq("Post updated")

      reply.reload
      expect(reply.content).to eq(newcontent)
      expect(reply.character_id).to eq(char.id)
      expect(reply.icon_id).to eq(icon.id)
      expect(reply.character_alias_id).to eq(calias.id)
    end

    it "preserves reply_order" do
      reply_post = create(:post)
      login_as(reply_post.user)
      create(:reply, post: reply_post)
      reply = create(:reply, post: reply_post)
      expect(reply.reply_order).to eq(2)
      expect(reply_post.replies.ordered.last).to eq(reply)
      create(:reply, post: reply_post)
      expect(reply_post.replies.ordered.last).not_to eq(reply)
      reply_post.mark_read(reply_post.user)
      put :update, params: { id: reply.id, reply: {content: 'new content'} }
      expect(reply.reload.reply_order).to eq(2)
    end

    context "preview" do
      it "takes correct actions" do
        Reply.auditing_enabled = true
        user = create(:user)
        reply_post = create(:post, user: user)
        reply = create(:reply, post: reply_post, user: user)
        login_as(user)
        expect(ReplyDraft.count).to eq(0)

        char = create(:character, user: user)
        icon = create(:icon, user: user)
        calias = create(:alias, character: char)
        char2 = create(:template_character, user: user)
        newcontent = reply.content + 'new'
        expect(controller).to receive(:build_template_groups).and_call_original
        expect(controller).to receive(:setup_layout_gon).and_call_original

        post :update, params: {
          id: reply.id,
          button_preview: true,
          reply: {
            content: newcontent,
            character_id: char.id,
            icon_id: icon.id,
            character_alias_id: calias.id
          }
        }

        expect(response).to render_template(:preview)
        expect(assigns(:javascripts)).to include('posts/editor')
        expect(assigns(:page_title)).to eq(reply_post.subject)
        expect(assigns(:post)).to eq(reply_post)
        expect(assigns(:reply)).to eq(reply)
        expect(ReplyDraft.count).to eq(0)
        expect(assigns(:audits)).to eq({reply.id => 1})

        written = assigns(:reply)
        expect(written).not_to be_a_new_record
        expect(written.user).to eq(reply_post.user)
        expect(written.character).to eq(char)
        expect(written.icon).to eq(icon)
        expect(written.character_alias).to eq(calias)

        # check it still remembers its current attributes, since this is a preview
        persisted = written.reload
        expect(persisted.user).to eq(reply_post.user)
        expect(persisted.character).to be_nil
        expect(persisted.icon).to be_nil
        expect(persisted.character_alias).to be_nil

        # build_template_groups:
        expect(controller.gon.editor_user[:username]).to eq(user.username)
        # templates
        templates = assigns(:templates)
        expect(templates.length).to eq(3)
        used = templates.first
        expect(used.name).to eq("Thread characters")
        expect(used.plucked_characters).to eq([[char.id, char.name]])
        expect(templates[1]).to eq(char2.template)
        templateless = templates.last
        expect(templateless.name).to eq('Templateless')
        expect(templateless.plucked_characters).to eq([[char.id, char.name]])
        Reply.auditing_enabled = false
      end

      it "takes correct actions for moderators" do
        user = create(:user)
        reply_post = create(:post, user: user)
        reply = create(:reply, post: reply_post, user: user)
        char = create(:template_character, user: user)
        login_as(create(:mod_user))

        newcontent = reply.content + 'new'

        post :update, params: {
          id: reply.id,
          button_preview: true,
          reply: {
            content: newcontent,
            audit_comment: 'note'
          }
        }

        expect(response).to render_template(:preview)
        expect(assigns(:reply).user).to eq(reply.user)
        expect(assigns(:reply).audit_comment).to eq('note')
        expect(assigns(:reply).content).to eq(newcontent)

        expect(controller.gon.editor_user[:username]).to eq(user.username)
        expect(assigns(:templates)).to eq([char.template])
      end

      skip
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid reply" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Post could not be found.")
    end

    it "requires post access" do
      reply = create(:reply)
      expect(reply.user_id).not_to eq(reply.post.user_id)
      expect(reply.post.visible_to?(reply.user)).to eq(true)

      reply.post.update!(privacy: :private)
      reply.reload
      expect(reply.post.visible_to?(reply.user)).to eq(false)

      login_as(reply.user)
      delete :destroy, params: { id: reply.id }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You do not have permission to view this post.")
    end

    it "requires reply access" do
      reply = create(:reply)
      login
      delete :destroy, params: { id: reply.id }
      expect(response).to redirect_to(post_url(reply.post))
      expect(flash[:error]).to eq("You do not have permission to modify this post.")
    end

    it "succeeds for reply creator" do
      reply = create(:reply)
      login_as(reply.user)
      delete :destroy, params: { id: reply.id }
      expect(response).to redirect_to(post_url(reply.post, page: 1))
      expect(flash[:success]).to eq("Reply deleted.")
      expect(Reply.find_by_id(reply.id)).to be_nil
    end

    it "succeeds for admin user" do
      reply = create(:reply)
      login_as(create(:admin_user))
      delete :destroy, params: { id: reply.id }
      expect(response).to redirect_to(post_url(reply.post, page: 1))
      expect(flash[:success]).to eq("Reply deleted.")
      expect(Reply.find_by_id(reply.id)).to be_nil
    end

    it "respects per_page when redirecting" do
      reply = create(:reply) # p1
      reply = create(:reply, post: reply.post, user: reply.user) # p1
      reply = create(:reply, post: reply.post, user: reply.user) # p2
      reply = create(:reply, post: reply.post, user: reply.user) # p2
      login_as(reply.user)
      delete :destroy, params: { id: reply.id, per_page: 2 }
      expect(response).to redirect_to(post_url(reply.post, page: 2))
    end

    it "respects per_page when redirecting first on page" do
      reply = create(:reply) # p1
      reply = create(:reply, post: reply.post, user: reply.user) # p1
      reply = create(:reply, post: reply.post, user: reply.user) # p2
      reply = create(:reply, post: reply.post, user: reply.user) # p2
      reply = create(:reply, post: reply.post, user: reply.user) # p3
      login_as(reply.user)
      delete :destroy, params: { id: reply.id, per_page: 2 }
      expect(response).to redirect_to(post_url(reply.post, page: 2))
    end

    it "deletes post author on deleting only reply in open posts" do
      user = create(:user)
      post = create(:post)
      expect(post.authors_locked).to eq(false)
      login_as(user)
      reply = create(:reply, post: post, user: user)
      post_user = post.post_authors.find_by(user: user)
      id = post_user.id
      expect(post_user.joined).to eq(true)
      delete :destroy, params: { id: reply.id }
      expect(Post::Author.find_by(id: id)).to be_nil
    end

    it "sets joined to false on deleting only reply when invited" do
      user = create(:user)
      other_user = create(:user)
      post = create(:post, user: other_user, authors: [user, other_user], authors_locked: true)
      expect(post.authors_locked).to eq(true)
      expect(post.post_authors.find_by(user: user)).not_to be_nil
      login_as(user)
      reply = create(:reply, post: post, user: user)
      post_user = post.post_authors.find_by(user: user)
      expect(post_user.joined).to eq(true)
      delete :destroy, params: { id: reply.id }
      post_user.reload
      expect(post_user.joined).to eq(false)
    end

    it "does not clean up post author when other replies exist" do
      user = create(:user)
      post = create(:post)
      expect(post.authors_locked).to eq(false)
      login_as(user)
      create(:reply, post: post, user: user) # remaining reply
      reply = create(:reply, post: post, user: user)
      post_user = post.post_authors.find_by(user: user)
      expect(post_user.joined).to eq(true)
      delete :destroy, params: { id: reply.id }
      post_user.reload
      expect(post_user.joined).to eq(true)
    end

    it "handles destroy failure" do
      post = create(:post)
      reply = create(:reply, user: post.user, post: post)
      login_as(post.user)
      expect(reply.reply_order).to eq(1)
      expect_any_instance_of(Reply).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: reply.id }
      expect(response).to redirect_to(reply_url(reply, anchor: "reply-#{reply.id}"))
      expect(flash[:error]).to eq({message: "Reply could not be deleted.", array: []})
      expect(post.reload.replies.find_by(reply_order: 1)).to eq(reply)
    end
  end

  describe "POST restore" do
    before(:each) { Reply.auditing_enabled = true }

    after(:each) { Reply.auditing_enabled = false }

    it "requires login" do
      post :restore, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "must find the reply" do
      expect(Reply.find_by_id(99)).to be_nil
      expect(Audited::Audit.find_by(auditable_id: 99)).to be_nil
      login
      post :restore, params: { id: 99 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Reply could not be found.")
    end

    it "must be a deleted reply" do
      reply = create(:reply)
      Audited::Audit.where(action: 'create').find_by(auditable_id: reply.id).update!(action: 'destroy')
      login_as(reply.user)
      post :restore, params: { id: 99 }
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("Reply could not be found.")
    end

    it "must be your reply" do
      rpost = create(:post)
      reply = create(:reply, post: rpost)
      login_as(rpost.user)
      reply.destroy!
      post :restore, params: { id: reply.id }
      expect(response).to redirect_to(post_url(rpost))
      expect(flash[:error]).to eq('You do not have permission to modify this post.')
    end

    it "handles mid reply deletion" do
      rpost = create(:post)
      replies = create_list(:reply, 4, post: rpost, user: rpost.user)
      deleted_reply = replies[2]
      deleted_reply.destroy!
      Timecop.freeze(rpost.reload.tagged_at + 1.day) { create(:reply, post: rpost, user: rpost.user) }
      post_attributes = Post.find_by_id(rpost.id).attributes

      login_as(rpost.user)
      post :restore, params: { id: deleted_reply.id }

      expect(Reply.find_by_id(deleted_reply.id)).to eq(deleted_reply)
      reloaded_post = Post.find_by_id(rpost.id)
      new_attributes = reloaded_post.attributes
      post_attributes.each do |key, val|
        expect(new_attributes[key]).to eq(val)
      end
      expect(reloaded_post.replies.pluck(:reply_order).sort).to eq(0.upto(5).to_a)
    end

    it "handles first reply deletion" do
      rpost = create(:post)
      replies = create_list(:reply, 2, post: rpost, user: rpost.user)
      deleted_reply = replies.first
      deleted_reply.destroy!
      Timecop.freeze(rpost.reload.tagged_at + 1.day) { create(:reply, post: rpost, user: rpost.user) }
      post_attributes = Post.find_by_id(rpost.id).attributes

      login_as(rpost.user)
      post :restore, params: { id: deleted_reply.id }

      expect(Reply.find_by_id(deleted_reply.id)).to eq(deleted_reply)
      reloaded_post = Post.find_by_id(rpost.id)
      new_attributes = reloaded_post.attributes
      post_attributes.each do |key, val|
        expect(new_attributes[key]).to eq(val)
      end
      expect(reloaded_post.replies.pluck(:reply_order).sort).to eq(0.upto(3).to_a)
    end

    it "handles last reply deletion" do
      rpost = create(:post)
      create_list(:reply, 2, post: rpost, user: rpost.user)
      deleted_reply = Timecop.freeze(rpost.reload.tagged_at + 1.day) { create(:reply, post: rpost) }
      deleted_reply.destroy!
      post_attributes = Post.find_by_id(rpost.id).attributes

      login_as(deleted_reply.user)
      post :restore, params: { id: deleted_reply.id }

      expect(Reply.find_by_id(deleted_reply.id)).to eq(deleted_reply)
      reloaded_post = Post.find_by_id(rpost.id)
      new_attributes = reloaded_post.attributes
      post_attributes.each do |key, val|
        next if %w(last_reply_id last_user_id updated_at tagged_at).include?(key.to_s)
        expect(new_attributes[key]).to eq(val), "#{key}s did not match, #{new_attributes[key]} should have been #{val}"
      end
      expect(reloaded_post.last_user).to eq(deleted_reply.user)
      expect(reloaded_post.last_reply).to eq(deleted_reply)
      expect(reloaded_post.replies.pluck(:reply_order).sort).to eq(0.upto(3).to_a)
    end

    it "handles only reply deletion" do
      rpost = create(:post)
      expect(rpost.last_user).to eq(rpost.user)
      expect(rpost.last_reply).to eq(rpost.written)

      deleted_reply = Timecop.freeze(rpost.reload.tagged_at + 1.day) { create(:reply, post: rpost) }
      rpost = Post.find(rpost.id)
      expect(rpost.last_user).to eq(deleted_reply.user)
      expect(rpost.last_reply).to eq(deleted_reply)

      deleted_reply.destroy!
      rpost = Post.find(rpost.id)
      expect(rpost.last_user).to eq(rpost.user)
      expect(rpost.last_reply).to eq(rpost.written)

      login_as(deleted_reply.user)
      post :restore, params: { id: deleted_reply.id }
      rpost = Post.find(rpost.id)
      expect(deleted_reply.reload.reply_order).to eq(1)
      expect(rpost.last_user).to eq(deleted_reply.user)
      expect(rpost.last_reply).to eq(deleted_reply)
    end

    it "does not allow restoring something already restored" do
      reply = create(:reply)
      reply.destroy!
      login_as(reply.user)
      post :restore, params: { id: reply.id }
      expect(flash[:success]).to eq("Reply has been restored!")
      post :restore, params: { id: reply.id }
      expect(flash[:error]).to eq("Reply does not need restoring.")
      expect(response).to redirect_to(post_url(reply.post))
    end

    it "correctly restores a previously restored reply" do
      reply = create(:reply, content: 'not yet restored')
      reply.destroy!
      login_as(reply.user)
      post :restore, params: { id: reply.id }
      expect(flash[:success]).to eq("Reply has been restored!")

      reply = Reply.find(reply.id)
      reply.content = 'restored right'
      reply.save!
      reply.destroy!

      post :restore, params: { id: reply.id }
      expect(flash[:success]).to eq("Reply has been restored!")
      reply = Reply.find(reply.id)
      expect(reply.content).to eq('restored right')
    end

    it "does not update post status" do
      rpost = create(:post)
      reply = create(:reply, post: rpost, user: rpost.user)
      create(:reply, post: rpost, user: rpost.user)
      reply.destroy!

      rpost.update!(status: :hiatus)
      login_as(rpost.user)
      post :restore, params: { id: reply.id }
      expect(flash[:success]).to eq("Reply has been restored!")
      expect(Post.find(rpost.id)).to be_hiatus
    end
  end

  describe "GET search" do
    context "no search" do
      before(:each) do
        2.times do
          create(:user)
          create(:character)
          create(:template_character)
        end
      end

      it "works logged out" do
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Replies')
        expect(assigns(:post)).to be_nil
        expect(assigns(:search_results)).to be_nil
        expect(assigns(:users)).to be_nil # this will be dynamically loaded
        expect(assigns(:characters)).to be_nil # this will be dynamically loaded
        expect(assigns(:users)).to be_nil # this will be dynamically loaded
        expect(assigns(:templates).size).to eq(2) # this will be dynamically loaded
      end

      it "works logged in" do
        login
        get :search
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Replies')
        expect(assigns(:post)).to be_nil
        expect(assigns(:search_results)).to be_nil
      end

      it "sets templates by author" do
        author = create(:user)
        template = create(:template, user: author)
        create(:template)
        get :search, params: { commit: true, author_id: author.id }
        expect(assigns(:templates)).to eq([template])
      end

      it "handles invalid post" do
        get :search, params: { post_id: -1 }
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Replies')
        expect(assigns(:post)).to be_nil
        expect(assigns(:search_results)).to be_nil
      end

      it "handles valid post" do
        templateless_char = Character.where(template_id: nil).first
        post = create(:post, character: templateless_char, user: templateless_char.user)
        create(:reply, post: post)
        user_ignoring_tags = create(:user)
        create(:reply, post: post, user: user_ignoring_tags)
        post.opt_out_of_owed(user_ignoring_tags)

        get :search, params: { post_id: post.id }
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Search Replies')
        expect(assigns(:post)).to eq(post)
        expect(assigns(:search_results)).to be_nil
        expect(assigns(:users)).to match_array(post.joined_authors)
        expect(assigns(:characters)).to match_array([post.written.character])
        expect(assigns(:templates)).to be_empty
      end

      it "sorts templates" do
        user = create(:user)
        login_as(user)
        template3 = create(:template, user: user, name: "c")
        template1 = create(:template, user: user, name: "a")
        template2 = create(:template, user: user, name: "b")
        get :search, params: { commit: true, author_id: user.id }
        expect(assigns(:templates)).to eq([template1, template2, template3])
      end

      it "sorts characters and templates when a post is given" do
        user = create(:user)
        login_as(user)
        template3 = create(:template, user: user, name: "c")
        template1 = create(:template, user: user, name: "a")
        template2 = create(:template, user: user, name: "b")
        char3 = create(:character, template: template3, user: user, name: "c")
        char1 = create(:character, template: template1, user: user, name: "a")
        char2 = create(:character, template: template2, user: user, name: "b")
        post = create(:post, user: user, character: char2)
        create(:reply, user: user, post: post, character: char1)
        create(:reply, user: user, post: post, character: char3)
        get :search, params: { post_id: post.id }
        expect(assigns(:templates)).to eq([template1, template2, template3])
        expect(assigns(:characters)).to eq([char1, char2, char3])
      end
    end

    context "searching" do
      it "finds all when no arguments given" do
        create_list(:reply, 4)
        get :search, params: { commit: true }
        expect(assigns(:search_results)).to match_array(Reply.all)
      end

      it "filters by author" do
        replies = Array.new(4) { create(:reply) }
        filtered_reply = replies.last
        get :search, params: { commit: true, author_id: filtered_reply.user_id }
        expect(assigns(:search_results)).to match_array([filtered_reply])
      end

      it "filters by icon" do
        create(:reply, with_icon: true)
        reply = create(:reply, with_icon: true)
        get :search, params: { commit: true, icon_id: reply.icon_id }
        expect(assigns(:search_results)).to match_array([reply])
      end

      it "filters by character" do
        create(:reply, with_character: true)
        reply = create(:reply, with_character: true)
        get :search, params: { commit: true, character_id: reply.character_id }
        expect(assigns(:search_results)).to match_array([reply])
      end

      it "filters by string" do
        reply = create(:reply, content: 'contains seagull')
        cap_reply = create(:reply, content: 'Seagull is capital')
        create(:reply, content: 'nope')
        get :search, params: { commit: true, subj_content: 'seagull' }
        expect(assigns(:search_results)).to match_array([reply, cap_reply])
      end

      it "filters by exact match" do
        create(:reply, content: 'contains forks')
        create(:reply, content: 'Forks is capital')
        reply = create(:reply, content: 'Forks High is capital')
        create(:reply, content: 'Forks high is kinda capital')
        create(:reply, content: 'forks High is different capital')
        create(:reply, content: 'forks high is not capital')
        create(:reply, content: 'Forks is split from High')
        create(:reply, content: 'nope')
        get :search, params: { commit: true, subj_content: '"Forks High"' }
        expect(assigns(:search_results)).to match_array([reply])
      end

      it "only shows from visible posts" do
        reply1 = create(:reply, content: 'contains forks')
        reply2 = create(:reply, content: 'visible contains forks')
        reply1.post.update!(privacy: :private)
        expect(reply1.post.reload).not_to be_visible_to(nil) # logged out, not visible
        expect(reply2.post.reload).to be_visible_to(nil)
        get :search, params: { commit: true, subj_content: 'forks' }
        expect(assigns(:search_results)).to match_array([reply2])
      end

      it "filters by post" do
        replies = Array.new(4) { create(:reply) }
        filtered_reply = replies.last
        get :search, params: { commit: true, post_id: filtered_reply.post_id }
        expect(assigns(:search_results)).to match_array([filtered_reply.post.written, filtered_reply])
      end

      it "requires visible post if given" do
        reply1 = create(:reply)
        reply1.post.update!(privacy: :private)
        expect(reply1.post.reload).not_to be_visible_to(nil)
        get :search, params: { commit: true, post_id: reply1.post_id }
        expect(assigns(:search_results)).to be_nil
        expect(flash[:error]).to eq('You do not have permission to view this post.')
      end

      it "filters by continuity" do
        continuity_post = create(:post, num_replies: 1)
        create(:post, num_replies: 1) # wrong post
        filtered_reply = continuity_post.replies.last
        get :search, params: { commit: true, board_id: continuity_post.board_id }
        expect(assigns(:search_results)).to match_array([continuity_post.written, filtered_reply])
      end

      it "filters by template" do
        character = create(:template_character)
        templateless_char = create(:character)
        reply = create(:reply, character: character, user: character.user)
        create(:reply, character: templateless_char, user: templateless_char.user)
        get :search, params: { commit: true, template_id: character.template_id }
        expect(assigns(:search_results)).to match_array([reply])
      end

      it "sorts by created desc" do
        reply = create(:post).written
        reply2 = Timecop.freeze(reply.created_at + 2.minutes) do
          create(:post).written
        end
        get :search, params: { commit: true, sort: 'created_new' }
        expect(assigns(:search_results)).to eq([reply2, reply])
      end

      it "sorts by created asc" do
        reply = create(:post).written
        reply2 = Timecop.freeze(reply.created_at + 2.minutes) do
          create(:post).written
        end
        get :search, params: { commit: true, sort: 'created_old' }
        expect(assigns(:search_results)).to eq([reply, reply2])
      end

      it "calculates audits" do
        Reply.auditing_enabled = true
        user = create(:user)

        replies = Audited.audit_class.as_user(user) do
          create_list(:reply, 6, user: user)
        end

        Audited.audit_class.as_user(user) do
          replies[1].touch # rubocop:disable Rails/SkipsModelValidations
          replies[3].update!(character: create(:character, user: user))
          replies[2].update!(content: 'new content')
          1.upto(5) { |i| replies[4].update!(content: 'message' + i.to_s) }
        end
        Audited.audit_class.as_user(create(:mod_user)) do
          replies[5].update!(content: 'new content')
        end

        counts = replies.map(&:id).zip([1, 1, 2, 2, 6, 2]).to_h
        writtens = replies.collect{ |r| r.post.written.id }
        writtens.each { |id| counts[id] = 1 }

        get :search, params: { commit: true, sort: 'created_old' }
        expect(assigns(:audits)).to eq(counts)
        Reply.auditing_enabled = false
      end
    end
  end
end
