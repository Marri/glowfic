RSpec.describe Board do
  include ActiveJob::TestHelper

  describe "validations" do
    it "succeeds" do
      expect(create(:board)).to be_valid
    end

    it "succeeds with multiple boards with a single creator" do
      user = create(:user)
      create(:board, creator: user)
      second = build(:board, creator: user)
      expect(second).to be_valid
      expect { second.save! }.not_to raise_error
    end

    it "should require a name" do
      board = build(:board, name: '')
      expect(board).not_to be_valid
      board.name = 'Name'
      expect(board).to be_valid
    end

    it "should require a unique name" do
      create(:board, name: 'Test Board')
      board = build(:board, name: 'Test Board')
      expect(board).not_to be_valid
      board.name = 'Name'
      expect(board).to be_valid
    end
  end

  it "should allow everyone to post if open to anyone" do
    board = create(:board)
    user = create(:user)
    expect(board.authors_locked?).to be false
    expect(user.writes_in?(board)).to be true
  end

  describe "coauthors" do
    it "should list the correct writers" do
      board = create(:board)
      coauthor = create(:user)
      cameo = create(:user)
      create(:user) # not_board
      board.board_authors.create!(user: coauthor)
      board.board_authors.create!(user: cameo, cameo: true)
      board.reload
      expect(board.writer_ids).to match_array([board.creator_id, coauthor.id])
    end

    it "should allow coauthors and cameos to post" do
      coauthor = create(:user)
      cameo = create(:user)
      board = create(:board, writers: [coauthor], cameos: [cameo], authors_locked: true)
      expect(board.authors_locked?).to be true
      expect(coauthor.writes_in?(board)).to be true
      expect(cameo.writes_in?(board)).to be true
    end

    it "should allow coauthors but not cameos to edit" do
      board = create(:board)
      coauthor = create(:user)
      cameo = create(:user)
      board.board_authors.create!(user: coauthor)
      board.board_authors.create!(user: cameo, cameo: true)
      board.reload
      expect(board.editable_by?(coauthor)).to be true
      expect(board.editable_by?(cameo)).to be false
    end

    it "should allow coauthors only once per board" do
      board = create(:board)
      board2 = create(:board)
      coauthor = create(:user)
      create(:user)
      board.board_authors.create!(user: coauthor)
      expect { board.board_authors.create!(user: coauthor) }.to raise_error(ActiveRecord::RecordInvalid)
      board2.board_authors.create!(user: coauthor)
      board.reload
      board2.reload
      expect(board.board_authors.count).to eq(2)
      expect(board2.board_authors.count).to eq(2)
    end
  end

  describe "#fix_ordering" do
    let(:board) { create(:board) }

    it "should work" do
      post = create(:post, board: board)
      create_list(:post, 3, board: board)
      post.update_columns(section_order: 2) # rubocop:disable Rails/SkipsModelValidations
      section = create(:board_section, board: board)
      create_list(:board_section, 2, board: board)
      section.update_columns(section_order: 6) # rubocop:disable Rails/SkipsModelValidations
      expect(board.posts.ordered_in_section.pluck(:section_order)).to eq([1, 2, 2, 3])
      expect(board.board_sections.ordered.pluck(:section_order)).to eq([1, 2, 6])
      board.send(:fix_ordering)
      expect(board.posts.ordered_in_section.pluck(:section_order)).to eq([0, 1, 2, 3])
      expect(board.board_sections.ordered.pluck(:section_order)).to eq([0, 1, 2])
    end

    it "should do nothing if board is ordered" do
      posts = create_list(:post, 4, board: board)
      posts = Post.where(id: posts.map(&:id)).ordered_in_section
      sections = create_list(:board_section, 3, board: board)
      sections = BoardSection.where(id: sections.map(&:id)).ordered
      expect {
        board.send(:fix_ordering)
      }.to not_change{posts.pluck(:section_order)}.and not_change { sections.pluck(:section_order) }
    end
  end

  describe "#ordered?" do
    it "should be unordered for default board" do
      expect(create(:board).ordered?).to eq(false)
    end

    it "should be ordered if board is not open to anyone" do
      board = create(:board, authors_locked: true)
      expect(board.ordered?).to eq(true)
      board.update!(authors_locked: false)
      expect(board.ordered?).to eq(false)
    end

    it "should be ordered if board has sections" do
      board = create(:board)
      create(:board_section, board: board)
      expect(board.ordered?).to eq(true)
    end
  end

  it "deletes sections but moves posts to sandboxes" do
    board = create(:board)
    create(:board, id: Board::ID_SANDBOX)
    section = create(:board_section, board: board)
    post = create(:post, board: board, section: section)
    perform_enqueued_jobs(only: UpdateModelJob) do
      Audited.audit_class.as_user(board.creator) { board.destroy! }
    end
    post.reload
    expect(post.board_id).to eq(3)
    expect(post.section).to be_nil
    expect(BoardSection.find_by_id(section.id)).to be_nil
  end

  describe "#open_to?" do
    let(:board) { create(:board, authors_locked: true) }
    let(:user) { create(:user) }

    it "requires a user" do
      expect(board.open_to?(nil)).to eq(false)
    end

    it "returns true for open boards" do
      board.update!(authors_locked: false)
      expect(board.open_to?(user)).to eq(true)
    end

    it "returns true for creator" do
      expect(board.open_to?(board.creator)).to eq(true)
    end

    it "returns true for board authors" do
      board.writers << user
      expect(board.open_to?(user)).to eq(true)
    end

    it "returns false for others" do
      expect(board.open_to?(user)).to eq(false)
    end
  end

  describe "#editable_by?" do
    let(:board) { create(:board, authors_locked: false) }
    let(:user) { create(:user) }

    it "requires a user" do
      expect(board.editable_by?(nil)).to eq(false)
    end

    it "returns true for creator" do
      expect(board.editable_by?(board.creator)).to eq(true)
    end

    it "returns true for admins" do
      expect(board.editable_by?(create(:admin_user))).to eq(true)
    end

    it "returns false if creator is deleted" do
      board.creator.update!(deleted: true)
      board.writers << user
      expect(board.editable_by?(user)).to eq(false)
    end

    it "returns true for board coauthors" do
      board.writers << user
      expect(board.editable_by?(user)).to eq(true)
    end

    it "returns false for others" do
      expect(board.editable_by?(user)).to eq(false)
    end
  end

  describe "#mark_read" do
    let(:board) { create(:board) }
    let(:user) { create(:user) }
    let(:now) { Time.zone.now }

    context "with new view" do
      let(:view) { BoardView.find_by(board: board, user: user) }

      it "uses at_time if specified" do
        time = now + 1.day
        board.mark_read(user, at_time: time)
        expect(view.read_at).to be_the_same_time_as(time)
      end

      it "uses current time without at_time" do
        Timecop.freeze(now) { board.mark_read(user) }
        expect(view.read_at).to be_the_same_time_as(now)
      end
    end

    context "with existing view" do
      let!(:view) { create(:board_view, board: board, user: user, read_at: now - 2.days) }

      it "uses current time without at_time" do
        Timecop.freeze(now) { board.mark_read(user) }
        expect(view.reload.read_at).to be_the_same_time_as(now)
      end

      it "uses later at_time if given" do
        time = now + 1.day
        board.mark_read(user, at_time: time)
        expect(view.reload.read_at).to be_the_same_time_as(time)
      end

      it "does not use earlier at_time unless forced" do
        expect { board.mark_read(user, at_time: now - 5.days) }.not_to change { view.read_at }
      end

      it "uses earlier at_time if forced" do
        time = now - 5.days
        board.mark_read(user, at_time: time, force: true)
        expect(view.reload.read_at).to be_the_same_time_as(time)
      end
    end
  end
end
