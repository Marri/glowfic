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
    before(:each) do ResqueSpec.reset! end

    it "does nothing if skip_notify is set" do
      notified_user = create(:user, email_notifications: true)
      post = create(:post, user: notified_user)

      create(:reply, post: post, skip_notify: true)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does nothing if the previous reply was yours" do
      notified_user = create(:user, email_notifications: true)
      post = create(:post, user: notified_user)

      reply = create(:reply, post: post, skip_notify: true)

      create(:reply, post: post, user: reply.user)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "does nothing if the post was yours on the first reply" do
      notified_user = create(:user, email_notifications: true)
      post = create(:post, user: notified_user)

      create(:reply, post: post, user: notified_user)
      expect(UserMailer).to have_queue_size_of(0)
    end

    it "sends to all other active authors if previous reply wasn't yours" do
      post = create(:post)
      expect(post.user.email_notifications).not_to eq(true)

      user = create(:user)
      user.update_columns(email: nil) # rubocop:disable Rails/SkipsModelValidations
      create(:reply, user: user, post: post, skip_notify: true)

      notified_user = create(:user, email_notifications: true)
      create(:reply, user: notified_user, post: post, skip_notify: true)

      another_notified_user = create(:user, email_notifications: true)
      create(:reply, user: another_notified_user, post: post, skip_notify: true)

      # skips users who have the post set as ignored for tags owed purposes (or who can't tag)
      a_user_who_doesnt_owe = create(:user, email_notifications: true)
      create(:reply, user: a_user_who_doesnt_owe, post: post, skip_notify: true)
      post.author_for(a_user_who_doesnt_owe).opt_out_of_owed

      reply = create(:reply, post: post)
      expect(UserMailer).to have_queue_size_of(2)
      expect(UserMailer).to have_queued(:post_has_new_reply, [notified_user.id, reply.id])
      expect(UserMailer).to have_queued(:post_has_new_reply, [another_notified_user.id, reply.id])
    end

    it "sends if the post was yours but previous reply wasn't" do
      notified_user = create(:user, email_notifications: true)
      post = create(:post, user: notified_user)

      another_notified_user = create(:user, email_notifications: true)
      create(:reply, user: another_notified_user, post: post, skip_notify: true)

      reply = create(:reply, post: post, user: notified_user)
      expect(UserMailer).to have_queue_size_of(1)
      expect(UserMailer).to have_queued(:post_has_new_reply, [another_notified_user.id, reply.id])
    end
  end

  describe "#has_edit_audits?" do
    shared_examples 'has_edit_audits' do |get_has_edit_audits|
      let(:user) { create(:user) }
      before(:each) { Reply.auditing_enabled = true }

      after(:each) { Reply.auditing_enabled = false }

      it "is false if reply has never been edited" do
        reply = nil
        Audited.audit_class.as_user(user) do
          reply = create(:reply, content: 'original', user: user)
        end
        expect(get_has_edit_audits.call(reply.id)).to eq(false)
      end

      it "is false if reply has just been touched" do
        reply = nil
        Audited.audit_class.as_user(user) do
          reply = create(:reply, content: 'original', user: user)
          reply.touch # rubocop:disable Rails/SkipsModelValidations
        end
        expect(get_has_edit_audits.call(reply.id)).to eq(false)
      end

      it "is true if reply has been edited in content" do
        reply = nil
        Audited.audit_class.as_user(user) do
          reply = create(:reply, content: 'original', user: user)
          reply.update!(content: 'blah')
        end
        expect(get_has_edit_audits.call(reply.id)).to eq(true)
      end

      it "is true if reply has been edited in character" do
        reply = nil
        Audited.audit_class.as_user(user) do
          reply = create(:reply, content: 'original', user: user)
          char = create(:character, user: user)
          reply.update!(character: char)
        end
        expect(get_has_edit_audits.call(reply.id)).to eq(true)
      end

      it "is true if reply has been edited many times" do
        reply = nil
        Audited.audit_class.as_user(user) do
          reply = create(:reply, content: 'original', user: user)
          1.upto(5) { |i| reply.update!(content: 'message' + i.to_s) }
        end
        expect(get_has_edit_audits.call(reply.id)).to eq(true)
      end

      it "is true if reply has been edited by moderator" do
        reply = nil
        Audited.audit_class.as_user(user) do
          reply = create(:reply, content: 'original')
        end
        Audited.audit_class.as_user(create(:mod_user)) do
          reply.update!(content: 'blah')
        end
        expect(get_has_edit_audits.call(reply.id)).to eq(true)
      end
    end

    context "with 'edit audit count' scope" do
      method = Proc.new do |reply_id|
        Reply.with_edit_audit_counts.find_by(id: reply_id).has_edit_audits?
      end
      include_examples 'has_edit_audits', method
    end

    context "without 'edit audit count' scope" do
      method = Proc.new do |reply_id|
        Reply.find_by(id: reply_id).has_edit_audits?
      end
      include_examples 'has_edit_audits', method
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
      first_reply = create(:reply, post: post)
      second_reply = create(:reply, post: post)
      third_reply = create(:reply, post: post)
      expect(post.replies.ordered).to eq([first_reply, second_reply, third_reply])
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
      first_reply = create(:reply, post: post)
      second_reply = create(:reply, post: post)
      third_reply = create(:reply, post: post)
      second_reply.update_columns(reply_order: 2) # rubocop:disable Rails/SkipsModelValidations
      third_reply.update_columns(reply_order: 1) # rubocop:disable Rails/SkipsModelValidations
      expect(post.replies.ordered).to eq([first_reply, third_reply, second_reply])
    end
  end
end
