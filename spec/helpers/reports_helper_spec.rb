RSpec.describe ReportsHelper do
  let(:user) { create(:user) }
  let(:post) { create(:post) }
  let(:view) { create(:post_view, user: user, post: post, read_at: now + 1.second) }
  let(:now) { Time.zone.now }

  before(:each) do
    Timecop.freeze(now) { create(:reply, post: post) }
    Timecop.freeze(now + 1.minute) { create(:reply, post: post) }
    assign(:opened_posts, Post::View.where(user_id: user.id).select([:post_id, :read_at, :ignored]))
  end

  describe "#has_unread?" do
    it "requires opened_posts" do
      assign(:opened_posts, nil)
      expect(helper.has_unread?(post)).to eq(false)
    end

    it "requires view" do
      expect(helper.has_unread?(post)).to eq(false)
    end

    it "returns false if ignored" do
      view.update!(ignored: true)
      expect(helper.has_unread?(post)).to eq(false)
    end

    it "returns false if fully unread" do
      view.update!(read_at: nil)
      expect(helper.has_unread?(post)).to eq(false)
    end

    it "returns true if tagged_at later than read_at" do
      expect(post.tagged_at).to be > view.read_at
      expect(helper.has_unread?(post)).to eq(true)
    end

    it "returns false if read_at later than tagged_at" do
      view.update!(read_at: now + 3.minutes)
      expect(post.tagged_at).to be < view.read_at
      expect(helper.has_unread?(post)).to eq(false)
    end
  end

  describe "#never_read?" do
    before(:each) do
      without_partial_double_verification do
        allow(helper).to receive(:logged_in?).and_return(true)
      end
    end

    it "requires login" do
      without_partial_double_verification do
        allow(helper).to receive(:logged_in?).and_return(false)
      end
      expect(helper.never_read?(post)).to eq(false)
    end

    it "returned true without opened posts" do
      assign(:opened_posts, nil)
      expect(helper.never_read?(post)).to eq(true)
    end

    it "returns true without view" do
      expect(helper.never_read?(post)).to eq(true)
    end

    it "returns false if ignored" do
      view.update!(ignored: true)
      expect(helper.never_read?(post)).to eq(false)
    end

    it "returns true with nil read_at" do
      view.update!(read_at: nil)
      expect(helper.never_read?(post)).to eq(true)
    end

    it "returns false with read_at" do
      expect(view.read_at).to be_present
      expect(helper.never_read?(post)).to eq(false)
    end
  end

  describe "#ignored?" do
    let(:board_view) { create(:board_view, user: user, board: post.board) }

    before(:each) { assign(:board_views, BoardView.where(user_id: user.id).select([:board_id, :ignored])) }

    it "requires opened posts" do
      assign(:opened_posts, nil)
      expect(helper.ignored?(post)).to eq(false)
    end

    it "requires view or board view" do
      expect(helper.ignored?(post)).to eq(false)
    end

    it "returns true if post ignored" do
      view.update!(ignored: true)
      expect(helper.ignored?(post)).to eq(true)
    end

    it "returns true if board ignored" do
      assign(:opened_posts, [create(:post_view, user: user)])
      board_view.update!(ignored: true)
      expect(helper.ignored?(post)).to eq(true)
    end

    it "returns false if not ignored" do
      view
      board_view
      expect(helper.ignored?(post)).to eq(false)
    end
  end
end
