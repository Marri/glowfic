RSpec.describe PostAuthor do
  describe "validations" do
    it 'succeeds' do
      expect(create(:post_author)).to be_valid
    end

    it 'suceeds with multiple posts and one user' do
      user = create(:user)
      post1 = create(:post)
      post2 = create(:post)
      create(:post_author, user: user, post: post1)
      second = build(:post_author, user: user, post: post2)
      expect(second).to be_valid
      expect {
        second.save!
      }.not_to raise_error
    end

    it 'succeeds with one post and multiple users' do
      user1 = create(:user)
      user2 = create(:user)
      post = create(:post)
      create(:post_author, user: user1, post: post)
      second = build(:post_author, user: user2, post: post)
      expect(second).to be_valid
      expect {
        second.save!
      }.not_to raise_error
    end

    it "should require a user" do
      post_author = build(:post_author, user: nil)
      expect(post_author).not_to be_valid
      post_author.user = create(:user)
      expect(post_author).to be_valid
    end

    it "should require a post" do
      post_author = build(:post_author, post: nil)
      expect(post_author).not_to be_valid
      post_author.post = create(:post)
      expect(post_author).to be_valid
    end

    it "should enforce uniqueness for a specific user and post" do
      user = create(:user)
      post = create(:post)
      create(:post_author, user: user, post: post) # post_author

      new_author = build(:post_author, user: user, post: post)
      expect(new_author).not_to be_valid
      expect {
        new_author.save!
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#opt_out_of_owed" do
    it "removes owedness if user previously could owe" do
      post = create(:post)
      post_author = post.author_for(post.user)
      expect(post_author.reload.can_owe).to eq(true)
      post_author.opt_out_of_owed
      expect(post_author.reload.can_owe).to eq(false)
    end

    it "destroys if not joined" do
      user = create(:user)
      post = create(:post, unjoined_authors: [user])
      post_author = post.author_for(user)
      expect(post_author.reload.can_owe).to eq(true)
      post_author.opt_out_of_owed
      expect(post.author_for(user)).to be_nil
    end
  end
end
