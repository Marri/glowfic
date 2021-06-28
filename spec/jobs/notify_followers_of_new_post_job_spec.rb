RSpec.describe NotifyFollowersOfNewPostJob do
  include ActiveJob::TestHelper
  before(:each) { clear_enqueued_jobs }

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
    let(:title) { 'test subject' }

    shared_examples "new" do
      it "works" do
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, unjoined_authors: [coauthor], board: board, subject: title)
          end
        }.to change { Message.count }.by(1)
        author_msg = Message.where(recipient: notified).last
        expect(author_msg.subject).to include("New post by #{author.username}")
        expected = "#{author.username} has just posted a new post entitled #{title} in the #{board.name} continuity with #{coauthor.username}."
        expect(author_msg.message).to include(expected)
      end

      it "does not send for private posts" do
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, board: board, privacy: :private)
          end
        }.not_to change { Message.count }
      end

      it "does not send to non-viewers for access-locked posts" do
        unnotified = create(:user)
        create(:favorite, user: unnotified, favorite: favorite)
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, board: board, unjoined_authors: [coauthor], privacy: :access_list, viewers: [coauthor, notified])
          end
        }.to change { Message.count }.by(1)
        expect(Message.where(recipient: unnotified)).not_to be_present
      end

      it "does not send if reader has config disabled" do
        notified.update!(favorite_notifications: false)
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, board: board)
          end
        }.not_to change { Message.count }
      end

      it "does not send to coauthors" do
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, board: board, unjoined_authors: [notified])
          end
        }.not_to change { Message.count }
      end

      it "does not queue on imported posts" do
        create(:post, user: author, board: board, is_import: true)
        expect(NotifyFollowersOfNewPostJob).not_to have_been_enqueued
      end
    end

    context "with favorited author" do
      let(:favorite) { author }

      before(:each) { create(:favorite, user: notified, favorite: author) }

      include_examples "new"

      it "works for self-threads" do
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, unjoined_authors: [], board: board, subject: title)
          end
        }.to change { Message.count }.by(1)

        author_msg = Message.where(recipient: notified).last
        expect(author_msg.subject).to eq("New post by #{author.username}")
        expect(author_msg.message).to include("#{author.username} has just posted a new post entitled #{title} in the #{board.name} continuity.")
      end
    end

    context "with favorited board" do
      let(:favorite) { board }

      before(:each) { create(:favorite, user: notified, favorite: board) }

      include_examples "new"

      it "does not send twice if the user has favorited both the poster and the continuity" do
        create(:favorite, user: notified, favorite: author)
        expect {
          perform_enqueued_jobs do
            create(:post, user: author, board: board)
          end
        }.to change { Message.count }.by(1)
      end

      it "does not send to the poster" do
        expect {
          perform_enqueued_jobs do
            create(:post, user: notified, board: board)
          end
        }.not_to change { Message.count }
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
end
