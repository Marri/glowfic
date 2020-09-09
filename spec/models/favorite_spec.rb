RSpec.describe Favorite do
  describe "validations" do
    let(:f) { Favorite.new }
    let(:f2) { Favorite.new }

    it "should require a user" do
      f.favorite = create(:post)
      expect(f).not_to be_valid
    end

    it "should require a favorite" do
      f.user = create(:user)
      expect(f).not_to be_valid
    end

    it "should not allow you to favorite yourself" do
      f.user = f.favorite = create(:user)
      expect(f).not_to be_valid
    end

    it "should not allow you to favorite something twice" do
      f.user = f2.user = create(:user)
      f.favorite = f2.favorite = create(:post)

      expect(f).to be_valid
      expect(f2).to be_valid
      expect(f.save).to eq(true)
      expect(f2).not_to be_valid
    end

    it "should allow you to favorite something someone else did" do
      f.user = create(:user)
      f2.user = create(:user)
      f.favorite = f2.favorite = create(:post)

      expect(f).to be_valid
      expect(f2).to be_valid
      expect(f.save).to eq(true)
      expect(f2.save).to eq(true)
    end

    it "should allow you to favorite multiple things" do
    end
  end
end
