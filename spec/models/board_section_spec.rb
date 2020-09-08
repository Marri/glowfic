RSpec.describe BoardSection do
  include ActiveJob::TestHelper

  let(:board) { create(:board) }

  it "should reset section_* fields in posts after deletion" do
    sections = create_list(:board_section, 3, board: board)
    section2 = sections[2]
    post = create(:post, board: board, section: sections[1])
    expect(post.section_id).not_to be_nil
    expect(post.section_order).to eq(0)
    expect(section2.section_order).to eq(2)
    perform_enqueued_jobs(only: UpdateModelJob) do
      Audited.audit_class.as_user(board.creator) do
        sections[1].destroy!
      end
    end
    post.reload
    expect(post.section_id).to be_nil
    expect(post.section_order).to eq(0)
    expect(section2.reload.section_order).to eq(1)
  end

  it "should autofill post section order when not specified" do
    section = create(:board_section, board: board)
    posts = create_list(:post, 3, board: board, section: section)
    expect(posts.map(&:section_order)).to eq([0, 1, 2])
  end

  it "should autofill board section order when not specified" do
    sections = create_list(:board_section, 3, board: board)
    expect(sections.map(&:section_order)).to eq([0, 1, 2])
  end

  it "should reorder upon deletion" do
    create_list(:board_section, 4, board: board)
    sections = board.sections
    expect(sections.map(&:section_order)).to eq([0, 1, 2, 3])
    Audited.audit_class.as_user(board.creator) { sections[1].destroy! }
    expect(sections.reload.map(&:section_order)).to eq([0, 1, 2])
  end

  it "should reorder upon board change" do
    create_list(:board_section, 4, board: board)
    sections = board.sections
    expect(sections.map(&:section_order)).to eq([0, 1, 2, 3])
    sections[1].update!(board: create(:board))
    expect(sections.reload.map(&:section_order)).to eq([0, 1, 2])
  end
end
