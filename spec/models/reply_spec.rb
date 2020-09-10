RSpec.describe Reply do
  describe "#has_icons?" do
    let(:user) { create(:user) }

    context "without character" do
      let(:reply) { create(:reply, user: user) }

      it "is true with avatar" do
        icon = create(:icon, user: user)
        user.update!(avatar: icon)
        user.reload

        expect(reply.character).to be_nil
        expect(reply.has_icons?).to eq(true)
      end

      it "is false without avatar" do
        expect(reply.character).to be_nil
        expect(reply.has_icons?).not_to eq(true)
      end
    end

    context "with character" do
      let(:character) { create(:character, user: user) }
      let(:reply) { create(:reply, user: user, character: character) }

      it "is true with default icon" do
        icon = create(:icon, user: user)
        character.update!(default_icon: icon)
        expect(reply.has_icons?).to eq(true)
      end

      it "is false without galleries" do
        expect(reply.has_icons?).not_to eq(true)
      end

      it "is true with icons in galleries" do
        gallery = create(:gallery, user: user)
        gallery.icons << create(:icon, user: user)
        character.galleries << gallery
        expect(reply.has_icons?).to eq(true)
      end

      it "is false without icons in galleries" do
        character.galleries << create(:gallery, user: user)
        expect(reply.has_icons?).not_to eq(true)
      end
    end
  end

  describe "#notify_other_authors" do
    let(:notified_user) { create(:user, email_notifications: true) }
    let(:post) { create(:post, user: notified_user) }
    let(:another_notified_user) { create(:user, email_notifications: true) }

    before(:each) { ResqueSpec.reset! }

    it "does nothing if skip_notify is set" do
      create(:reply, post: post, skip_notify: true)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does nothing if the previous reply was yours" do
      reply = create(:reply, post: post, skip_notify: true)
      create(:reply, post: post, user: reply.user)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does nothing if the post was yours on the first reply" do
      create(:reply, post: post, user: notified_user)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does not send to authors with notifications off" do
      post = create(:post, user: create(:user, email_notifications: false))
      create(:reply, post: post)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does not send to emailless users" do
      notified_user.update_columns(email: nil) # rubocop:disable Rails/SkipsModelValidations
      create(:reply, post: post)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does not send to users who have opted out of owed" do
      post.opt_out_of_owed(notified_user)
      create(:reply, post: post)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "sends to all other active authors if previous reply wasn't yours" do
      create(:reply, user: another_notified_user, post: post, skip_notify: true)

      reply = create(:reply, post: post)
      expect(UserMailer).to have_queue_size_of(2)
      expect(UserMailer).to have_queued(:post_has_new_reply, [notified_user.id, reply.id])
      expect(UserMailer).to have_queued(:post_has_new_reply, [another_notified_user.id, reply.id])
    end

    it "sends if the post was yours but previous reply wasn't" do
      create(:reply, user: another_notified_user, post: post, skip_notify: true)

      reply = create(:reply, post: post, user: notified_user)
      expect(UserMailer).to have_queue_size_of(1)
      expect(UserMailer).to have_queued(:post_has_new_reply, [another_notified_user.id, reply.id])
    end
  end

  describe "authors interactions" do
    it "does not update can_owe upon creating a reply" do
      post = create(:post)
      reply = create(:reply, post: post)

      expect(post.author_for(reply.user).can_owe).to be(true)
      create(:reply, user: reply.user, post: post)
      expect(post.author_for(reply.user).can_owe).to be(true)

      author = post.author_for(reply.user)
      author.can_owe = false
      author.save!

      expect(post.author_for(reply.user).can_owe).to be(false)
      create(:reply, user: reply.user, post: post)
      expect(post.author_for(reply.user).can_owe).to be(false)
    end
  end

  describe ".ordered" do
    let(:post) { create(:post) }

    it "orders replies" do
      replies = create_list(:reply, 3, post: post)
      expect(post.replies.ordered).to eq(replies)
    end

    it "orders replies by reply_order, not created_at" do
      first_reply = Timecop.freeze(post.created_at + 1.second) { create(:reply, post: post) }
      second_reply = Timecop.freeze(first_reply.created_at - 5.seconds) { create(:reply, post: post) }
      third_reply = Timecop.freeze(first_reply.created_at - 3.seconds) { create(:reply, post: post) }
      expect(post.replies.ordered).not_to eq(post.replies.order(:created_at))
      expect(post.replies.order(:created_at)).to eq([second_reply, third_reply, first_reply])
      expect(post.replies.ordered).to eq([first_reply, second_reply, third_reply])
    end

    it "orders replies by reply order not ID" do
      replies = create_list(:reply, 3, post: post)
      replies[1].update_columns(reply_order: 2) # rubocop:disable Rails/SkipsModelValidations
      replies[2].update_columns(reply_order: 1) # rubocop:disable Rails/SkipsModelValidations
      expect(post.replies.ordered).to eq([replies[0], replies[2], replies[1]])
    end
  end
end
