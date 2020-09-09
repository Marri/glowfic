RSpec.describe IndexPost do
  let(:user) { create(:user) }
  let(:index) { create(:index, user: user) }

  it "should autofill post section order on creation" do
    post2 = create(:post, user: user)
    post0 = create(:post, user: user)
    post1 = create(:post, user: user)
    posts = [post0, post1, post2]
    index.posts << posts
    expect(IndexPost.count).to eq(3)
    expect(index.reload.posts.count).to eq(3)
    expect(posts.map{|p| p.index_posts.first.section_order}).to eq([0, 1, 2])
  end

  it "should reorder upon deletion" do
    posts = create_list(:post, 3, user: user)
    index.posts << posts
    expect(posts.map{|p| p.index_posts.first.section_order}).to eq([0, 1, 2])
    post1 = posts[1]
    index.posts.destroy(post1)
    expect(posts.map{|p| p.index_posts.first&.section_order}).to eq([0, nil, 1])
  end
end
