RSpec.describe IndexSection do
  let(:user) { create(:user) }
  let(:index) { create(:index, user: user) }

  it "should autofill post section order when not specified" do
    section = create(:index_section, index: index)
    post2 = create(:post, user: user)
    post0 = create(:post, user: user)
    post1 = create(:post, user: user)
    posts = [post0, post1, post2]
    section.posts << posts
    expect(IndexPost.count).to eq(3)
    expect(section.reload.posts.count).to eq(3)
    expect(posts.map{|p| p.index_posts.first.section_order}).to eq([0, 1, 2])
  end

  it "should autofill board section order on creation" do
    sections = create_list(:index_section, 3, index: index)
    expect(sections.map(&:section_order)).to eq([0, 1, 2])
  end

  it "should reorder upon deletion" do
    sections = create_list(:index_section, 4, index: index)
    expect(sections.map(&:section_order)).to eq([0, 1, 2, 3])
    sections[1].destroy!
    expect(sections.map{|s| IndexSection.find_by(id: s.id)&.section_order }).to eq([0, nil, 1, 2])
  end

  it "should reorder upon index change" do
    sections = create_list(:index_section, 4, index: index)
    expect(sections.map(&:section_order)).to eq([0, 1, 2, 3])
    sections[1].update!(index: create(:index))
    expect(sections.map(&:section_order)).to eq([0, 0, 2, 3])
  end
end
