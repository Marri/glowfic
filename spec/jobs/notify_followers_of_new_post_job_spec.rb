RSpec.describe NotifyFollowersOfNewPostJob do
  before(:each) { ResqueSpec.reset! }

  it "does nothing with invalid post id" do
    expect(Favorite).not_to receive(:where)
    user = create(:user)
    NotifyFollowersOfNewPostJob.perform_now(-1, user.id)
  end

  it "does nothing with invalid user id" do
    expect(Favorite).not_to receive(:where)
    post = create(:post)
    NotifyFollowersOfNewPostJob.perform_now(post.id, -1)
  end

  context "on new posts" do
    let(:author) { create(:user) }
    let(:coauthor) { create(:user) }
    let(:notified) { create(:user) }
    let(:board) { create(:board) }

    it "works for board favorites" do
      create(:favorite, user: notified, favorite: board)
      post = create(:post, user: author, unjoined_authors: [coauthor], board: board)
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.to change { Message.count }.by(1)
      author_msg = Message.where(recipient: notified).last
      expect(author_msg.subject).to eq("New post by #{author.username}")
      expected = "#{author.username} has just posted a new post entitled #{post.subject} in the #{board.name} continuity with #{coauthor.username}."
      expect(author_msg.message).to include(expected)
    end

    it "works for user favorites" do
      create(:favorite, user: notified, favorite: author)
      post = create(:post, user: author, unjoined_authors: [coauthor], board: board)
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.to change { Message.count }.by(1)
      author_msg = Message.where(recipient: notified).last
      expect(author_msg.subject).to include("New post by #{author.username}")
      expected = "#{author.username} has just posted a new post entitled #{post.subject} in the #{board.name} continuity with #{coauthor.username}."
      expect(author_msg.message).to include(expected)
    end

    it "works for self-threads" do
      create(:favorite, user: notified, favorite: author)
      post = create(:post, user: author, unjoined_authors: [], subject: 'test')

      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.to change { Message.count }.by(1)

      author_msg = Message.where(recipient: notified).last
      expect(author_msg.subject).to eq("New post by #{author.username}")
      expect(author_msg.message).to include("#{author.username} has just posted a new post entitled test in the #{post.board.name} continuity.")
    end

    it "does not send twice if the user has favorited both the poster and the continuity" do
      create(:favorite, user: notified, favorite: board)
      create(:favorite, user: notified, favorite: author)
      post = create(:post, user: author, board: board)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id)
      }.to change { Message.count }.by(1)
    end

    it "does not send for private posts" do
      create(:favorite, user: notified, favorite: author)
      post = create(:post, user: author, privacy: :private)
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
    end

    it "does not send to non-viewers for access-locked posts" do
      unnotified = create(:user)
      create(:favorite, user: unnotified, favorite: author)
      create(:favorite, user: notified, favorite: author)
      post = create(:post, user: author, privacy: :access_list, viewers: [notified])
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.to change { Message.count }.by(1)
      expect(Message.where(recipient: unnotified)).not_to be_present
    end

    it "does not send if reader has config disabled" do
      notified.update!(favorite_notifications: false)
      create(:favorite, user: notified, favorite: author)
      post = create(:post, user: author)
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
    end

    it "does not send to the poster" do
      create(:favorite, user: author, favorite: board)
      post = create(:post, user: author, board: board)
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
    end

    it "does not send to coauthors" do
      create(:favorite, user: author, favorite: notified)
      post = create(:post, user: author, unjoined_authors: [notified])
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
    end

    describe "with blocking" do
      let(:post) { create(:post, user: author, board: board, authors: [coauthor]) }

      before(:each) { create(:favorite, user: notified, favorite: board) }

      it "does not send to users the poster has blocked" do
        create(:block, blocking_user: author, blocked_user: notified, hide_me: :posts)
        expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
      end

      it "does not send to users a coauthor has blocked" do
        create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
        expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
      end

      it "does not send to users who are blocking the poster" do
        create(:block, blocked_user: author, blocking_user: notified, hide_them: :posts)
        expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
      end

      it "does not send to users who are blocking a coauthor" do
        create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
        expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
      end
    end
  end

  context "on joined posts" do
    it "does not send twice if the user has favorited both the poster and the replier" do
      author = create(:user)
      replier = create(:user)
      notified = create(:user)
      create(:favorite, user: notified, favorite: author)
      create(:favorite, user: notified, favorite: replier)

      post = create(:post, user: author)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id)
      }.to change { Message.count }.by(1)

      reply = create(:reply, post: post, user: replier)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, reply.user_id)
      }.not_to change { Message.count }
    end

    it "does not send twice if the poster changes their username" do
      author = create(:user)
      replier = create(:user)
      notified = create(:user)
      create(:favorite, user: notified, favorite: author)
      create(:favorite, user: notified, favorite: replier)

      post = create(:post, user: author)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id)
      }.to change { Message.count }.by(1)

      author.update!(username: "#{author.username}new")
      reply = create(:reply, post: post, user: replier)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, reply.user_id)
      }.not_to change { Message.count }
    end

    it "does not send twice if the post subject changes" do
      author = create(:user)
      replier = create(:user)
      notified = create(:user)
      create(:favorite, user: notified, favorite: author)
      create(:favorite, user: notified, favorite: replier)

      post = create(:post, user: author)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id)
      }.to change { Message.count }.by(1)

      post.update!(subject: "#{post.subject}new")
      reply = create(:reply, post: post, user: replier)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, reply.user_id)
      }.not_to change { Message.count }
    end

    it "sends twice for different posts" do
      author = create(:user)
      replier = create(:user)
      notified = create(:user)
      create(:favorite, user: notified, favorite: author)
      create(:favorite, user: notified, favorite: replier)

      post = create(:post, user: author)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id)
      }.to change { Message.count }.by(1)

      not_favorited_post = create(:post)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(not_favorited_post.id, not_favorited_post.user_id)
      }.not_to change { Message.count }

      reply = create(:reply, post: not_favorited_post, user: replier)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(not_favorited_post.id, reply.user_id)
      }.to change { Message.count }.by(1)
    end

    it "sends the right message" do
      author = create(:user)
      notified = create(:user)
      create(:favorite, user: notified, favorite: author)

      post = create(:post)
      reply = create(:reply, post: post, user: author)
      expect {
        NotifyFollowersOfNewPostJob.perform_now(post.id, reply.user_id)
      }.to change { Message.count }.by(1)

      message = Message.last
      expect(message.subject).to eq("#{author.username} has joined a new thread")
      expect(message.message).to include(post.subject)
      expect(message.message).to include("with #{post.user.username}")
    end

    it "does not send unless visible" do
      author = create(:user)
      notified = create(:user)
      create(:favorite, user: notified, favorite: author)
      post = create(:post, privacy: :access_list, viewers: [author])
      create(:reply, post: post, user: author) # reply
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, author.id) }.not_to change { Message.count }
    end

    it "does not send if reader has config disabled" do
      author = create(:user)
      notified = create(:user, favorite_notifications: false)
      create(:favorite, user: notified, favorite: author)
      post = create(:post)
      create(:reply, post: post, user: author) # reply
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, author.id) }.not_to change { Message.count }
    end

    it "does not send to the poster" do
      author = create(:user)
      favorite = create(:user)
      create(:favorite, user: author, favorite: favorite)
      post = create(:post, user: author)
      create(:reply, post: post, user: favorite) # reply
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, favorite.id) }.not_to change { Message.count }
    end

    it "does not send to coauthors" do
      author = create(:user)
      coauthor1 = create(:user)
      coauthor2 = create(:user)
      create(:favorite, user: coauthor1, favorite: coauthor2)
      post = create(:post, user: author, unjoined_authors: [coauthor1, coauthor2])
      create(:reply, post: post, user: coauthor2)
      expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
    end

    describe "with blocking" do
      let(:board) { create(:board) }
      let(:author) { create(:user) }
      let(:coauthor) { create(:user) }
      let(:notified) { create(:user) }
      let(:post) { create(:post, user: author, board: board) }

      before(:each) do
        create(:favorite, user: notified, favorite: board)
        create(:reply, post: post, user: coauthor)
      end

      it "does not send to users the joining user has blocked" do
        create(:block, blocking_user: coauthor, blocked_user: notified, hide_me: :posts)
        expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
      end

      it "does not send to users who are blocking the joining user" do
        create(:block, blocked_user: coauthor, blocking_user: notified, hide_them: :posts)
        expect { NotifyFollowersOfNewPostJob.perform_now(post.id, post.user_id) }.not_to change { Message.count }
      end
    end
  end
end
