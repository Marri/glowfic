RSpec.describe Message do
  describe "validations" do
    let(:message) { build(:message) }

    it "cannot have a nil sender" do
      message.sender = nil
      expect(message).not_to be_valid
    end

    it "can have a zero sender_id to represent site messages" do
      message.sender_id = 0
      expect(message).to be_valid
      expect(message.sender_name).to eq('Glowfic Constellation')
    end
  end

  describe "#notify_recipient" do
    before(:each) { ResqueSpec.reset! }

    it "does not send with notifications off" do
      message = create(:message)
      expect(message.recipient.email_notifications).not_to eq(true)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does not send with no email" do
      user = create(:user)
      user.update_columns(email: nil) # rubocop:disable Rails/SkipsModelValidations
      create(:message, recipient: user)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "sends with notifications on" do
      notified_user = create(:user, email_notifications: true)
      message = create(:message, recipient: notified_user)

      expect(UserMailer).to have_queue_size_of(1)
      expect(UserMailer).to have_queued(:new_message, [message.id])
    end

    it "does not notify blocking recipients" do
      recipient = create(:user, email_notifications: true)
      block = create(:block, block_interactions: true, blocking_user: recipient)
      create(:message, sender: block.blocked_user, recipient: recipient)
      expect(UserMailer).to have_queue_size_of(0)
    end
  end

  context "with blocks" do
    let(:blocker) { create(:user) }
    let(:blocked) { create(:user) }

    before(:each) { create(:block, blocking_user: blocker, blocked_user: blocked, block_interactions: true) }

    it "hides blocked messages from recipient without erroring to sender" do
      message = build(:message, sender: blocked, recipient: blocker)
      expect(message.save).to be(true)
      expect(message.visible_inbox).to eq(false)
      expect(message.unread).to eq(false)
    end

    it "errors to sender if messaging a blocked user" do
      message = build(:message, sender: blocker, recipient: blocked)
      expect(message.save).to eq(false)
      expect(message.errors.full_messages.first).to eq("Recipient must not be blocked by you")
    end
  end

  it "does not error to blocked user if updating an existing message" do
    message = create(:message)
    create(:block, blocking_user: message.sender, blocked_user: message.recipient)
    expect(message.update(unread: false)).to be(true)
  end

  it "errors to sender if messaging a deleted user" do
    message = build(:message, recipient: create(:user, deleted: true))
    expect(message).not_to be_valid
    expect(message.recipient).to be_nil
  end
end
