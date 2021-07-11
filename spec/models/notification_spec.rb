RSpec.describe Notification do
  describe "validations" do
    it "cannot have a nil user" do
      notification = build(:notification, user: nil)
      expect(notification).not_to be_valid
    end

    it "must have a valid type" do
      expect { build(:notification, notification_type: :foo) }.to raise_error(ArgumentError)
    end

    it "can have a nil post" do
      notification = build(:notification, post: nil)
      expect(notification).to be_valid
    end
  end

  describe "#notify_recipient" do
    before(:each) { ResqueSpec.reset! }

    skip "does not send with notifications off" do
      notification = create(:notification)
      expect(notification.user.email_notifications).not_to eq(true)
      expect(UserMailer).to have_queue_size_of(0)
    end

    skip "does not send with no email" do
      user = create(:user)
      user.update_columns(email: nil) # rubocop:disable Rails/SkipsModelValidations
      create(:notification, user: user)
      expect(UserMailer).to have_queue_size_of(0)
    end

    skip "sends with notifications on" do
      notified_user = create(:user, email_notifications: true)
      notification = create(:notification, user: notified_user)

      expect(UserMailer).to have_queue_size_of(1)
      expect(UserMailer).to have_queued(:new_notification, [notification.id])
    end
  end
end
