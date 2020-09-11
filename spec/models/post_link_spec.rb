RSpec.describe PostLink, type: :model do
  describe "validations" do
    it "requires linking post" do
      link = build(:post_link, linking_post: nil)
      expect(link).not_to be_valid
      link.linking_post = create(:post)
      expect(link).to be_valid
    end

    it "requires linked post" do
      link = build(:post_link, linked_post: nil)
      expect(link).not_to be_valid
      link.linked_post = create(:post)
      expect(link).to be_valid
    end

    it "requires different posts" do
      post = create(:post)
      link = build(:post_link, linking_post: post, linked_post: post)
      expect(link).not_to be_valid
    end

    it "requires relationship" do
      link = build(:post_link, relationship: nil)
      expect(link).not_to be_valid
    end

    it "succeeds" do
      expect(create(:post_link)).to be_valid
    end
  end
end
