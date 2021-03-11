RSpec.describe Post::View do
  describe "validations" do
    it "requires post" do
      view = build(:post_view, post: nil)
      expect(view).not_to be_valid
      expect(view.save).to eq(false)
    end

    it "requires user" do
      view = build(:post_view, user: nil)
      expect(view).not_to be_valid
      expect(view.save).to eq(false)
    end

    it "works with both user and post" do
      user = create(:user)
      post = create(:post)
      view = build(:post_view, user: user, post: post)
      expect(view).to be_valid
      expect(view.save).to eq(true)
      view.reload
      expect(view.user).to eq(user)
      expect(view.post).to eq(post)
    end

    it "is unique by post and user" do
      view = create(:post_view)
      new_view = build(:post_view, user: view.user, post: view.post)
      expect(new_view).not_to be_valid
      expect(new_view.save).to eq(false)
      expect {
        new_view.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows one user to have multiple post views" do
      user = create(:user)
      view = create(:post_view, user: user)
      new_view = build(:post_view, user: user, post: create(:post))
      expect(new_view.post).not_to eq(view.post)
      expect(new_view).to be_valid
      expect(new_view.save).to eq(true)
    end

    it "allows one post to have multiple users in post views" do
      post = create(:post)
      view = create(:post_view, post: post)
      new_view = build(:post_view, post: post)
      expect(new_view.user).not_to eq(view.user)
      expect(new_view).to be_valid
      expect(new_view.save).to eq(true)
    end
  end

  describe "mark_favorite_read" do
    include ActiveJob::TestHelper

    let(:user) { create(:user) }
    let(:post) { nil }

    before(:each) do
      clear_enqueued_jobs
    end

    def make_post
      favorited_user = create(:user)
      create(:favorite, user: user, favorite: favorited_user)

      expect(user.messages.count).to eq(0)
      post = perform_enqueued_jobs(only: NotifyFollowersOfNewPostJob) do
        create(:post, user: favorited_user)
      end
      expect(user.messages.count).to eq(1)
      expect(user.messages.first.unread).to be true
      post
    end

    it "updates message if unread" do
      post = make_post
      post.mark_read(user)
      expect(user.messages.first.unread).to eq(false)
    end

    it "does not update message if read" do
      post = make_post
      notification = user.messages.first
      notification.update!(unread: false)
      post.mark_read(user)
      expect(user.messages.first.unread).to eq(false)
    end
  end
end
