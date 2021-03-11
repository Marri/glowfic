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

  it "should be fixable via admin method" do
    board = create(:board)
    post = create(:post, board: board)
    create(:post, board: board) # post2
    create(:post, board: board) # post3
    create(:post, board: board) # post4
    post.update_columns(section_order: 2) # rubocop:disable Rails/SkipsModelValidations
    section = create(:board_section, board: board)
    create(:board_section, board: board) # section2
    create(:board_section, board: board) # section3
    section.update_columns(section_order: 6) # rubocop:disable Rails/SkipsModelValidations
    expect(board.posts.ordered_in_section.pluck(:section_order)).to eq([1, 2, 2, 3])
    expect(board.board_sections.ordered.pluck(:section_order)).to eq([1, 2, 6])
    board.send(:fix_ordering)
    expect(board.posts.ordered_in_section.pluck(:section_order)).to eq([0, 1, 2, 3])
    expect(board.board_sections.ordered.pluck(:section_order)).to eq([0, 1, 2])
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
end
