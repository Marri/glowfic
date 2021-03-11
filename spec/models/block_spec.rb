RSpec.describe Block, type: :model do
  describe "validations" do
    it 'succeeds' do
      expect(create(:block)).to be_valid
    end

    it "should require a blocking user" do
      block = build(:block, blocking_user: nil)
      expect(block).not_to be_valid
      block.blocking_user = create(:user)
      expect(block).to be_valid
    end

    it "should require a blocked user" do
      block = build(:block, blocked_user: nil)
      expect(block).not_to be_valid
      block.blocked_user = create(:user)
      expect(block).to be_valid
    end

    it "should enforce uniqueness for a specific set of users" do
      blocker = create(:user)
      blocked = create(:user)
      create(:block, blocking_user: blocker, blocked_user: blocked)

      new_block = build(:block, blocking_user: blocker, blocked_user: blocked)
      expect(new_block).not_to be_valid
      expect {
        new_block.save!
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should require a valid hide_them" do
      expect { build(:block, hide_them: -1) }.to raise_error(ArgumentError)
    end

    it "should require a valid hide_me" do
      expect { build(:block, hide_me: -1) }.to raise_error(ArgumentError)
    end

    it "should require an option to be set" do
      block = build(:block, hide_me: 0, hide_them: 0, block_interactions: false)
      expect(block).not_to be_valid
      expect { block.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'suceeds with multiple blocked users and one blocking user' do
      blocker = create(:user)
      blocked1 = create(:user)
      blocked2 = create(:user)
      create(:block, blocking_user: blocker, blocked_user: blocked1)
      second = build(:block, blocking_user: blocker, blocked_user: blocked2)
      expect(second).to be_valid
      expect {
        second.save!
      }.not_to raise_error
    end

    it 'succeeds with one blocked user and multiple blocking users' do
      blocked = create(:user)
      blocker1 = create(:user)
      blocker2 = create(:user)
      create(:block, blocking_user: blocker1, blocked_user: blocked)
      second = build(:block, blocking_user: blocker2, blocked_user: blocked)
      expect(second).to be_valid
      expect {
        second.save!
      }.not_to raise_error
    end
  end

  context "when hiding own content" do
    it "should allow full blocking" do
      block = create(:block, hide_me: :all)
      expect(block.hide_my_posts?).to be(true)
      expect(block.hide_me_all?).to be(true)
    end

    it "should allow posts-only blocking" do
      block = create(:block, hide_me: :posts)
      expect(block.hide_my_posts?).to be(true)
      expect(block.hide_me_all?).to be(false)
    end

    it "should allow no blocking" do
      block = create(:block, hide_me: :none)
      expect(block.hide_my_posts?).to be(false)
      expect(block.hide_my_posts?).to be(false)
    end
  end

  context "when hiding their content" do
    it "should allow full blocking" do
      block = create(:block, hide_them: :all)
      expect(block.hide_their_posts?).to be(true)
      expect(block.hide_them_all?).to be(true)
    end

    it "should allow posts-only blocking" do
      block = create(:block, hide_them: :posts)
      expect(block.hide_their_posts?).to be(true)
      expect(block.hide_them_all?).to be(false)
    end

    it "should allow no blocking" do
      block = create(:block, hide_them: :none)
      expect(block.hide_their_posts?).to be(false)
      expect(block.hide_them_all?).to be(false)
    end
  end

  it "should hide messages when first blocking" do
    message = create(:message)
    expect(message).to be_unread
    create(:block, blocking_user: message.recipient, blocked_user: message.sender, block_interactions: true)
    expect(message.reload).not_to be_unread
  end
end
