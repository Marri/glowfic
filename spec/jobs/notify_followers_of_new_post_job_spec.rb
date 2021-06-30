RSpec.describe NotifyFollowersOfNewPostJob do
  include ActiveJob::TestHelper
  before(:each) { clear_enqueued_jobs }

  context "validations" do
    it "does nothing with invalid post id" do
      expect(Favorite).not_to receive(:where)
      user = create(:user)
      NotifyFollowersOfNewPostJob.perform_now(-1, user.id, 'new')
    end

    it "does nothing with invalid user id on join" do
      expect(Favorite).not_to receive(:where)
      post = create(:post)
      NotifyFollowersOfNewPostJob.perform_now(post.id, -1, 'join')
    end

    it "does nothing with invalid user id on access" do
      expect(Favorite).not_to receive(:where)
      post = create(:post)
      NotifyFollowersOfNewPostJob.perform_now(post.id, -1, 'access')
    end

    it "does nothing with invalid action" do
      expect(Favorite).not_to receive(:where)
      post = create(:post)
      NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id, '')
    end
  end

  shared_examples "general" do
    it "works" do
      expect { perform_enqueued_jobs { do_action } }.to change { Message.count }.by(1)
      author_msg = Message.where(recipient: notified).last
      expect(author_msg.subject).to eq(msg_title)
      expect(author_msg.message).to include(msg_content)
    end

    it "does not send if reader has config disabled" do
      notified.update!(favorite_notifications: false)
      expect { perform_enqueued_jobs { do_action } }.not_to change { Message.count }
    end
  end

  shared_examples 'authors' do
    it "does not send to authors" do
      Favorite.delete_all
      authors = [author, coauthor, unjoined].reject{ |u| u == favorite }
      authors.each { |u| create(:favorite, user: u, favorite: favorite) }
      expect { perform_enqueued_jobs { do_action } }.not_to change { Message.count }
    end
  end

  shared_examples 'privacy' do
    it "does not send for private posts" do
      expect { perform_enqueued_jobs { do_action(privacy: :private) } }.not_to change { Message.count }
    end

    it "does not send to non-viewers for access-locked posts" do
      unnotified = create(:user)
      create(:favorite, user: unnotified, favorite: favorite)
      expect { perform_enqueued_jobs { do_action(privacy: :access_list, viewers: [coauthor, notified]) } }.to change { Message.count }.by(1)
      expect(Message.where(recipient: unnotified)).not_to be_present
    end
  end

  context "on new posts" do
    let(:author) { create(:user) }
    let(:coauthor) { create(:user) }
    let(:unjoined) { create(:user) }
    let(:notified) { create(:user) }
    let(:board) { create(:board) }
    let(:title) { 'test subject' }

    def do_action(privacy: :public, viewers: [])
      create(:post, user: author, unjoined_authors: [coauthor, unjoined], board: board, subject: title, privacy: privacy, viewers: viewers)
    end

    shared_examples "new" do
      let(:msg_content) do
        author_ids = [coauthor, unjoined].map(&:id)
        authors = User.where(id: author_ids).ordered.pluck(:username).join(' and ')
        "#{author.username} has just posted a new post with #{authors} entitled #{title} in the #{board.name} continuity."
      end

      include_examples 'general'
      include_examples 'authors'
      include_examples 'privacy'

      it "does not queue on imported posts" do
        create(:post, user: author, board: board, is_import: true)
        expect(NotifyFollowersOfNewPostJob).not_to have_been_enqueued
      end
    end

    context "with favorited author" do
      let(:favorite) { author }
      let(:msg_title) { "New post by #{author.username}" }

      before(:each) { create(:favorite, user: notified, favorite: author) }

      include_examples "new"

      it "works for self-threads" do
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, unjoined_authors: [], board: board, subject: title)
          end
        }.to change { Message.count }.by(1)

        author_msg = Message.where(recipient: notified).last
        expect(author_msg.subject).to eq(msg_title)
        expect(author_msg.message).to include("#{author.username} has just posted a new post entitled #{title} in the #{board.name} continuity.")
      end
    end

    context "with favorited coauthor" do
      let(:favorite) { coauthor }
      let(:msg_title) { "New post by #{coauthor.username}" }

      before(:each) { create(:favorite, user: notified, favorite: coauthor) }

      include_examples "new"
    end

    context "with favorited board" do
      let(:favorite) { board }
      let(:msg_title) { "New post in #{board.name}" }

      before(:each) { create(:favorite, user: notified, favorite: board) }

      include_examples "new"

      it "does not send twice if the user has favorited both the poster and the continuity" do
        create(:favorite, user: notified, favorite: author)
        expect {
          perform_enqueued_jobs { do_action }
        }.to change { Message.count }.by(1)
      end
    end

    describe "with blocking" do
      let(:post) { create(:post, user: author, board: board, authors: [coauthor]) }

      before(:each) { create(:favorite, user: notified, favorite: board) }

      it "does not send to users the poster has blocked" do
        create(:block, blocking_user: author, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { post } }.not_to change { Message.count }
      end

      it "does not send to users a coauthor has blocked" do
        create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { post } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking the poster" do
        create(:block, blocked_user: author, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { post } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking a coauthor" do
        create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { post } }.not_to change { Message.count }
      end
    end
  end

  context "on joined posts" do
    let(:author) { create(:user) }
    let(:replier) { create(:user) }
    let(:notified) { create(:user) }

    context "with both authors favorited" do
      before(:each) do
        create(:favorite, user: notified, favorite: author)
        create(:favorite, user: notified, favorite: replier)
      end

      it "does not send twice if the user has favorited both the poster and the replier" do
        expect {
          perform_enqueued_jobs do
            post = create(:post, user: author)
            create(:reply, post: post, user: replier)
          end
        }.to change { Message.count }.by(1)
      end

      it "does not send twice if the poster changes their username" do
        expect {
          perform_enqueued_jobs do
            post = create(:post, user: author)
            author.update!(username: author.username + 'new')
            create(:reply, post: post, user: replier)
          end
        }.to change { Message.count }.by(1)
      end

      it "does not send twice if the post subject changes" do
        expect {
          perform_enqueued_jobs do
            post = create(:post, user: author)
            post.update!(subject: post.subject + 'new')
            create(:reply, post: post, user: replier)
          end
        }.to change { Message.count }.by(1)
      end

      it "sends twice for different posts" do
        expect {
          perform_enqueued_jobs { create(:post, user: author) }
        }.to change { Message.count }.by(1)

        not_favorited_post = nil
        expect {
          perform_enqueued_jobs do
            not_favorited_post = create(:post)
          end
        }.not_to change { Message.count }

        expect {
          perform_enqueued_jobs do
            create(:reply, post: not_favorited_post, user: replier)
          end
        }.to change { Message.count }.by(1)
      end
    end

    context "with favorited replier" do
      before(:each) { create(:favorite, user: notified, favorite: replier) }

      it "sends the right message" do
        title = "test subject"

        expect {
          perform_enqueued_jobs do
            post = create(:post, user: author, subject: title)
            create(:reply, post: post, user: replier)
          end
        }.to change { Message.count }.by(1)

        message = Message.last
        expect(message.subject).to eq("#{replier.username} has joined a new thread")
        expect(message.message).to include(title)
        expect(message.message).to include("with #{author.username}")
      end

      it "does not send unless visible" do
        expect {
          perform_enqueued_jobs do
            post = create(:post, privacy: :access_list, viewers: [replier])
            create(:reply, post: post, user: replier)
          end
        }.not_to change { Message.count }
      end

      it "does not send if reader has config disabled" do
        notified.update!(favorite_notifications: false)
        expect { perform_enqueued_jobs { create(:reply, user: replier) } }.not_to change { Message.count }
      end

      it "does not queue on imported replies" do
        post = create(:post)
        clear_enqueued_jobs
        create(:reply, user: replier, post: post, is_import: true)
        expect(NotifyFollowersOfNewPostJob).not_to have_been_enqueued
      end
    end

    it "does not send to the poster" do
      create(:favorite, user: author, favorite: replier)
      expect {
        perform_enqueued_jobs do
          post = create(:post, user: author)
          create(:reply, post: post, user: replier)
        end
      }.not_to change { Message.count }
    end

    it "does not send to coauthors" do
      unjoined = create(:user)
      create(:favorite, user: unjoined, favorite: replier)
      expect {
        perform_enqueued_jobs do
          post = create(:post, user: author, unjoined_authors: [replier, unjoined])
          create(:reply, post: post, user: replier)
        end
      }.not_to change { Message.count }
    end

    describe "with blocking" do
      let(:coauthor) { create(:user) }
      let!(:post) { create(:post, user: author, unjoined_authors: [coauthor]) }
      let(:reply) { create(:reply, post: post, user: replier) }

      before(:each) { create(:favorite, user: notified, favorite: replier) }

      it "does not send to users the joining user has blocked" do
        create(:block, blocking_user: replier, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { reply } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking the joining user" do
        create(:block, blocked_user: replier, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { reply } }.not_to change { Message.count }
      end

      it "does not send to users the original poster has blocked" do
        create(:block, blocking_user: author, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { reply } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking the original poster" do
        create(:block, blocked_user: author, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { reply } }.not_to change { Message.count }
      end

      it "does not send to users who a coauthor has blocked" do
        create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { reply } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking a coauthor" do
        create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { reply } }.not_to change { Message.count }
      end
    end
  end

  context "on newly accessible posts" do
    let!(:author) { create(:user) }
    let!(:coauthor) { create(:user) }
    let!(:unjoined) { create(:user) }
    let!(:notified) { create(:user) }
    let!(:post) { create(:post, user: author, unjoined_authors: [coauthor, unjoined], privacy: :access_list, viewers: [coauthor, unjoined]) }

    before(:each) { create(:reply, user: coauthor, post: post) }

    def do_action
      PostViewer.create!(user: notified, post: post)
    end

    shared_examples "access" do
      let(:msg_content) do
        author_ids = [author, coauthor].map(&:id)
        authors = User.where(id: author_ids).ordered.pluck(:username).join(' and ')
        "You have been given access to a post by #{authors} entitled #{post.subject} in the #{post.board.name} continuity."
      end

      include_examples 'general'

      it "does not send on post creation" do
        board = post.board
        clear_enqueued_jobs
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, unjoined_authors: [coauthor, unjoined], board: board)
          end
        }.to change { Message.count }.by(1)

        author_msg = Message.where(recipient: notified).last
        expect(author_msg.subject).to include("New post")
      end

      it "does not send for public threads" do
        post.update!(privacy: :public)
        expect { perform_enqueued_jobs { do_action } }.not_to change { Message.count }
      end

      it "does not send for private threads" do
        post.update!(privacy: :private)
        expect { perform_enqueued_jobs { do_action } }.not_to change { Message.count }
      end

      it "does not send to coauthors" do
        PostViewer.delete_all
        [coauthor, unjoined].each do |u|
          next if u == favorite
          create(:favorite, user: u, favorite: author)
          expect {
            perform_enqueued_jobs { PostViewer.create!(user: u, post: post) }
          }.not_to change { Message.count }
        end
      end
    end

    context "with favorited author" do
      let(:favorite) { author }
      let(:msg_title) { "You now have access to a post by #{author.username}" }

      before(:each) { create(:favorite, user: notified, favorite: author) }

      include_examples "access"

      it "works for self-threads" do
        post = create(:post, user: author, privacy: :access_list)
        create(:reply, user: author, post: post)

        expect { perform_enqueued_jobs { PostViewer.create!(user: notified, post: post) } }.to change { Message.count }.by(1)

        author_msg = Message.where(recipient: notified).last
        expected = "You have been given access to a post by #{author.username} entitled #{post.subject} in the #{post.board.name} continuity."
        expect(author_msg.message).to include(expected)
      end
    end

    context "with favorited coauthor" do
      let(:favorite) { coauthor }
      let(:msg_title) { "You now have access to a post by #{coauthor.username}" }

      before(:each) { create(:favorite, user: notified, favorite: coauthor) }

      include_examples "access"
    end

    context "with favorited unjoined coauthor" do
      let(:favorite) { unjoined }
      let(:msg_title) { "You now have access to a post by #{unjoined.username}" }

      before(:each) { create(:favorite, user: notified, favorite: unjoined) }

      include_examples "access"
    end

    context "with favorited board" do
      let(:favorite) { post.board }
      let(:msg_title) { "You now have access to a post in #{post.board.name}" }

      before(:each) { create(:favorite, user: notified, favorite: post.board) }

      include_examples "access"

      it "does not send twice if the user has favorited both the poster and the continuity" do
        create(:favorite, user: notified, favorite: author)
        expect { perform_enqueued_jobs { do_action } }.to change { Message.count }.by(1)
      end
    end

    context "with privacy change" do
      before(:each) do
        create(:favorite, user: notified, favorite: author)
        post.update!(privacy: :private, viewers: [coauthor, unjoined, notified])
        clear_enqueued_jobs
      end

      it "works" do
        expect {
          perform_enqueued_jobs { post.update!(privacy: :access_list) }
        }.to change { Message.count }.by(1)
      end

      it "does not send twice for new viewer" do
        PostViewer.find_by(user: notified, post: post).destroy!
        post.reload
        expect {
          perform_enqueued_jobs do
            post.update!(privacy: :access_list, viewers: [coauthor, unjoined, notified])
          end
        }.to change { Message.count }.by(1)
      end

      it "does not send if already notified" do
        post.update!(privacy: :access_list, viewers: [coauthor, unjoined])
        expect {
          perform_enqueued_jobs { PostViewer.create!(user: notified, post: post) }
        }.to change { Message.count }.by(1)

        post.update!(privacy: :private)

        expect {
          perform_enqueued_jobs { post.update!(privacy: :access_list) }
        }.not_to change { Message.count }
      end

      it "does not send for public threads" do
        expect {
          perform_enqueued_jobs { post.update!(privacy: :public) }
        }.to change { Message.count }.by(1)
        expect(Message.where(recipient: notified).last.message).to include('published')
      end

      it "does not send for registered threads" do
        expect {
          perform_enqueued_jobs { post.update!(privacy: :registered) }
        }.to change { Message.count }.by(1)
        expect(Message.where(recipient: notified).last.message).to include('published')
      end

      it "does not send for previously public threads" do
        post.update!(privacy: :public)
        post.reload
        clear_enqueued_jobs
        expect { perform_enqueued_jobs { post.update!(privacy: :access_list) } }.not_to change { Message.count }
      end

      it "does not send if reader has config disabled" do
        notified.update!(favorite_notifications: false)
        expect {
          perform_enqueued_jobs { post.update!(privacy: :access_list) }
        }.not_to change { Message.count }
      end
    end

    context "with blocking" do
      let!(:post) { create(:post, user: author, authors: [coauthor]) }
      let(:viewer) { PostViewer.create!(user: notified, post: post) }

      before(:each) { create(:favorite, user: notified, favorite: post.board) }

      it "does not send to users the poster has blocked" do
        create(:block, blocking_user: author, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { viewer } }.not_to change { Message.count }
      end

      it "does not send to users a coauthor has blocked" do
        create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
        expect { perform_enqueued_jobs { viewer } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking the poster" do
        create(:block, blocked_user: author, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { viewer } }.not_to change { Message.count }
      end

      it "does not send to users who are blocking a coauthor" do
        create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
        expect { perform_enqueued_jobs { viewer } }.not_to change { Message.count }
      end
    end
  end

  context "on newly published posts" do
    let!(:author) { create(:user) }
    let!(:coauthor) { create(:user) }
    let!(:notified) { create(:user) }
    let!(:unjoined) { create(:user) }
    let!(:board) { create(:board) }
    let!(:post) { create(:post, user: author, board: board, authors: [coauthor, unjoined], privacy: :access_list) }

    before(:each) { create(:reply, user: coauthor, post: post)}

    [:registered, :public].each do |privacy|
      context "to #{privacy}" do
        let(:do_action) { post.update!(privacy: privacy) }

        shared_examples "publication" do
          let(:msg_content) do
            author_ids = [author, coauthor].map(&:id)
            authors = User.where(id: author_ids).ordered.pluck(:username).join(' and ')
            "#{authors} have published a post entitled #{post.subject} in the #{board.name} continuity."
          end

          include_examples 'general'
          include_examples 'authors'

          it "works for previously private posts" do
            post.update!(privacy: :private)
            clear_enqueued_jobs
            expect { perform_enqueued_jobs { do_action } }.to change { Message.count }.by(1)

            author_msg = Message.where(recipient: notified).last
            expected = "#{author.username} and #{coauthor.username} have published a post entitled #{post.subject} in the #{board.name} continuity."
            expect(author_msg.message).to include(expected)
          end

          it "does not send on post creation" do
            board = post.board
            clear_enqueued_jobs
            expect {
              perform_enqueued_jobs do
                create(:post, user: author, unjoined_authors: [coauthor, unjoined], board: board)
              end
            }.to change { Message.count }.by(1)

            author_msg = Message.where(recipient: notified).last
            expect(author_msg.message).not_to include('published')
          end
        end

        context "with favorited author" do
          let(:favorite) { author }
          let(:msg_title) { "New post by #{author.username}" }

          before(:each) { create(:favorite, user: notified, favorite: author) }

          include_examples "publication"

          it "works for self-threads" do
            post = create(:post, user: author, board: board, privacy: :access_list)
            create(:reply, post: post, user: author)

            expect {
              perform_enqueued_jobs { post.update!(privacy: privacy) }
            }.to change { Message.count }.by(1)

            author_msg = Message.where(recipient: notified).last
            expected = "#{author.username} has published a post entitled #{post.subject} in the #{board.name} continuity."
            expect(author_msg.message).to include(expected)
          end
        end

        context "with favorited coauthor" do
          let(:favorite) { coauthor }
          let(:msg_title) { "New post by #{coauthor.username}" }

          before(:each) { create(:favorite, user: notified, favorite: coauthor) }

          include_examples "publication"
        end

        context "with favorited board" do
          let(:favorite) { board }
          let(:msg_title) { "New post in #{board.name}" }

          before(:each) { create(:favorite, user: notified, favorite: board) }

          include_examples "publication"

          it "does not send twice if the user has favorited both the poster and the continuity" do
            create(:favorite, user: notified, favorite: author)
            expect {
              perform_enqueued_jobs { post.update!(privacy: privacy) }
            }.to change { Message.count }.by(1)
          end
        end

        context "with favorited unjoined coauthor" do
          let(:favorite) { unjoined }
          let(:msg_title) { "New post by #{unjoined.username}" }

          before(:each) { create(:favorite, user: notified, favorite: unjoined) }

          include_examples "publication"
        end

        context "with blocking" do
          before(:each) { create(:favorite, user: notified, favorite: board) }

          it "does not send to users the poster has blocked" do
            create(:block, blocking_user: author, blocked_user: notified, hide_me: :posts)
            expect { perform_enqueued_jobs { post.update!(privacy: privacy) } }.not_to change { Message.count }
          end

          it "does not send to users a coauthor has blocked" do
            create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
            expect { perform_enqueued_jobs { post.update!(privacy: privacy) } }.not_to change { Message.count }
          end

          it "does not send to users who are blocking the poster" do
            create(:block, blocked_user: author, blocking_user: notified, hide_them: :posts)
            expect { perform_enqueued_jobs { post.update!(privacy: privacy) } }.not_to change { Message.count }
          end

          it "does not send to users who are blocking a coauthor" do
            create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
            expect { perform_enqueued_jobs { post.update!(privacy: privacy) } }.not_to change { Message.count }
          end
        end
      end
    end
  end

  context "on revived posts" do
    let!(:author) { create(:user) }
    let!(:coauthor) { create(:user) }
    let!(:notified) { create(:user) }
    let!(:unjoined) { create(:user) }
    let!(:board) { create(:board) }

    shared_examples "reactivation" do
      shared_examples "active" do
        let(:msg_title) { "#{post.subject} resumed" }
        let(:msg_content) do
          author_ids = [author, coauthor].map(&:id)
          authors = User.where(id: author_ids).ordered.pluck(:username).join(' and ')
          "#{post.subject} by #{authors}, in the #{board.name} continuity, has been resumed."
        end

        include_examples 'general'
        include_examples 'authors'
        include_examples 'privacy'
      end

      context "with favorited author" do
        let(:favorite) { author }

        before(:each) { create(:favorite, user: notified, favorite: author) }

        include_examples 'active'

        it "works for self-threads" do
          post.last_reply.update_columns(user_id: author.id) # rubocop:disable Rails/SkipsModelValidations
          post.post_authors.where.not(user_id: author.id).delete_all

          expect { perform_enqueued_jobs { do_action} }.to change { Message.count }.by(1)

          author_msg = Message.where(recipient: notified).last
          expected = "#{post.subject} by #{author.username}, in the #{board.name} continuity, has been resumed."
          expect(author_msg.subject).to eq("#{post.subject} resumed")
          expect(author_msg.message).to include(expected)
        end

        it "works with only top post" do
          post.last_reply.destroy!
          expect { perform_enqueued_jobs { do_action} }.to change { Message.count }.by(1)
        end
      end

      context "with favorited coauthor" do
        let(:favorite) { coauthor }

        before(:each) { create(:favorite, user: notified, favorite: coauthor) }

        include_examples 'active'
      end

      context "with favorited unjoined coauthor" do
        let(:favorite) { unjoined }

        before(:each) { create(:favorite, user: notified, favorite: unjoined) }

        include_examples 'active'
      end

      context "with favorited board" do
        let(:favorite) { board }

        before(:each) { create(:favorite, user: notified, favorite: board) }

        include_examples 'active'

        it "does not send twice if the user has favorited both the poster and the continuity" do
          create(:favorite, user: notified, favorite: author)
          expect { perform_enqueued_jobs { do_action} }.to change { Message.count }.by(1)
        end
      end

      context "with favorited post" do
        let(:favorite) { post }

        before(:each) { create(:favorite, user: notified, favorite: post) }

        include_examples 'active'
      end

      context "with blocking" do
        before(:each) { create(:favorite, user: notified, favorite: board) }

        it "does not send to users the poster has blocked" do
          create(:block, blocking_user: author, blocked_user: notified, hide_me: :posts)
          expect { perform_enqueued_jobs { do_action} }.not_to change { Message.count }
        end

        it "does not send to users a coauthor has blocked" do
          create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
          expect { perform_enqueued_jobs { do_action} }.not_to change { Message.count }
        end

        it "does not send to users who are blocking the poster" do
          create(:block, blocked_user: author, blocking_user: notified, hide_them: :posts)
          expect { perform_enqueued_jobs { do_action} }.not_to change { Message.count }
        end

        it "does not send to users who are blocking a coauthor" do
          create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
          expect { perform_enqueued_jobs { do_action} }.not_to change { Message.count }
        end
      end
    end

    context "with abandoned posts" do
      let(:post) { create(:post, user: author, board: board, authors: [coauthor, unjoined]) }

      before(:each) do
        create(:reply, user: coauthor, post: post)
        post.update!(status: :abandoned)
      end

      def do_action(privacy: nil, viewers: [])
        post.update!(privacy: privacy, viewers: viewers) if privacy
        post.update!(status: :active)
      end

      include_examples "reactivation"
    end

    context "with manually hiatused posts" do
      let(:post) { create(:post, user: author, board: board, authors: [coauthor, unjoined]) }

      before(:each) do
        create(:reply, user: coauthor, post: post)
        post.update!(status: :hiatus)
      end

      def do_action(privacy: nil, viewers: [])
        post.update!(privacy: privacy, viewers: viewers) if privacy
        create(:reply, user: author, post: post)
      end

      include_examples "reactivation"
    end

    context "with auto-hiatused posts" do
      let(:now) { Time.zone.now }
      let!(:post) do
        Timecop.freeze(now - 2.months) do
          create(:post, user: author, board: board, authors: [coauthor, unjoined])
        end
      end

      before(:each) do
        Timecop.freeze(now - 2.months + 1.day) do
          create(:reply, user: coauthor, post: post)
        end
      end

      def do_action(privacy: nil, viewers: [])
        if privacy
          Timecop.freeze(now - 2.months) do
            post.update!(privacy: privacy, viewers: viewers)
          end
        end

        Timecop.freeze(now) do
          create(:reply, user: author, post: post)
        end
      end

      include_examples "reactivation"
    end
  end
end
