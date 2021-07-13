RSpec.describe Message do
  describe "validations" do
    it "cannot have a nil sender" do
      message = build(:message)
      message.sender = nil
      expect(message).not_to be_valid
    end

    it "can have a zero sender_id to represent site messages" do
      message = build(:message)
      message.sender_id = 0
      expect(message).to be_valid
      expect(message.sender_name).to eq('Glowfic Constellation')
    end
  end

  describe "#notify_recipient" do
    before(:each) do ResqueSpec.reset! end

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

  describe "#unread_count_for" do
    let(:user) { create(:user) }

    it "returns unread inbox count" do
      expect(Message.unread_count_for(user)).to eq(0)
      create_list(:message, 2, recipient: user)
      expect(Message.unread_count_for(user)).to eq(2)
    end

    it "clears cache on new inbox message" do
      create_list(:message, 2, recipient: user)
      expect(Message.unread_count_for(user)).to eq(2)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(true)
      create(:message, recipient: user)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(false)
      expect(Message.unread_count_for(user)).to eq(3)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(true)
    end

    it "clears cache when inbox message marked read" do
      create(:message, recipient: user)
      message = create(:message, recipient: user)
      create_list(:message, 2, recipient: user)
      expect(Message.unread_count_for(user)).to eq(4)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(true)
      message.update!(unread: false)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(false)
      expect(Message.unread_count_for(user)).to eq(3)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(true)
    end

    it "does not clear cache on unrelated message" do
      create_list(:message, 2, recipient: user)
      expect(Message.unread_count_for(user)).to eq(2)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(true)
      create(:message)
      expect(Rails.cache.exist?(Message.cache_string_for(user.id))).to eq(true)
    end
  end

  it "hides blocked messages from recipient without erroring to sender" do
    block = create(:block, block_interactions: true)
    message = build(:message, sender: block.blocked_user, recipient: block.blocking_user)
    expect(message.save).to be true
    expect(message.visible_inbox).to eq(false)
    expect(message.unread).to eq(false)
  end

  it "errors to sender if messaging a blocked user" do
    block = create(:block, block_interactions: true)
    message = build(:message, sender: block.blocking_user, recipient: block.blocked_user)
    expect(message.save).to eq(false)
    expect(message.errors.full_messages.first).to eq("Recipient must not be blocked by you")
  end

  it "does not error to blocked user if updating an existing message" do
    message = create(:message)
    create(:block, blocking_user: message.sender, blocked_user: message.recipient)
    message.unread = false
    message.save!
  end

  it "errors to sender if messaging a deleted user" do
    message = build(:message, recipient: create(:user, deleted: true))
    expect(message).not_to be_valid
    expect(message.recipient).to be_nil
  end

  describe "#unempty_subject" do
    let(:message) { create(:message) }

    it "returns thread parent subject" do
      reply = create(:message, thread_id: message.id)
      expect(reply.unempty_subject).to eq(message.subject)
    end

    it "works with empty subject" do
      message.update!(subject: '')
      expect(message.unempty_subject).to eq('(no title)')
    end

    it "returns subject" do
      expect(message.unempty_subject).to eq(message.subject)
    end
  end
end
