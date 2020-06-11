RSpec.describe User do
  describe "password encryption" do
    it "should support nil salt_uuid" do
      user = create(:user)
      user.update_columns(salt_uuid: nil, crypted: user.send(:old_crypted_password, 'test')) # rubocop:disable Rails/SkipsModelValidations
      user.reload
      expect(user.authenticate('test')).to eq(true)
    end

    it "should set and support salt_uuid" do
      user = create(:user, password: 'test')
      expect(user.salt_uuid).not_to be_nil
      expect(user.authenticate('test')).to eq(true)
    end
  end

  it "should be unique by username" do
    user = create(:user, username: 'testuser1')
    new_user = build(:user, username: user.username.upcase)
    expect(new_user).not_to be_valid
  end

  describe "reserved usernames" do
    it "should not allow users to use the site message placeholder" do
      user = build(:user, username: 'Glowfic Constellation')
      expect(user).not_to be_valid
    end

    it "should not allow users to use the deleted user placeholder" do
      user = build(:user, username: '(deleted user)')
      expect(user).not_to be_valid
    end
  end

  describe "emails" do
    def generate_emailless_user
      user = build(:user, email: '')
      user.send(:encrypt_password)
      user.save!(validate: false)
      user
    end

    it "should be unique by email case-insensitively" do
      user = create(:user, email: 'testuser1@example.com')
      new_user = build(:user, email: user.email.upcase)
      expect(new_user).not_to be_valid
    end

    it "should require emails on new accounts" do
      user = build(:user, email: '')
      expect(user).not_to be_valid
      user.email = 'testuser@example.com'
      expect(user).to be_valid
    end

    it "should allow users with no email to be changed" do
      generate_emailless_user # to have duplicate without email
      user = generate_emailless_user
      user.layout = 'starrydark'
      expect(user).to be_valid
      expect {
        user.save!
      }.not_to raise_error
    end

    it "should allow users with no email to get an email" do
      generate_emailless_user # to have duplicate without email
      user = generate_emailless_user
      user.email = 'testuser@example.com'
      expect(user).to be_valid
      expect {
        user.save!
      }.not_to raise_error
    end
  end

  describe "moieties" do
    it "allows blank moieties" do
      user = build(:user, moiety: '')
      expect(user).to be_valid
    end

    it "rejects invalid sizes" do
      user1 = build(:user, moiety: '12')
      expect(user1).not_to be_valid

      user2 = build(:user, moiety: '1234')
      expect(user2).not_to be_valid

      user3 = build(:user, moiety: '1234567')
      expect(user3).not_to be_valid
    end

    it "rejects invalid characters" do
      user1 = build(:user, moiety: '12345Z')
      expect(user1).not_to be_valid

      user2 = build(:user, moiety: '123 456')
      expect(user2).not_to be_valid
    end

    it "allows short moieties" do
      user = build(:user, moiety: 'ABC')
      expect(user).to be_valid
    end

    it "allows long moieties" do
      user = build(:user, moiety: '123ABC')
      expect(user).to be_valid
    end

    it "allows lowercase" do
      user = build(:user, moiety: '123abc')
      expect(user).to be_valid
    end
  end

  it "orders galleryless icons" do
    user = create(:user)
    icon3 = create(:icon, user: user, keyword: "c")
    icon4 = create(:icon, user: user, keyword: "d")
    icon1 = create(:icon, user: user, keyword: "a")
    icon2 = create(:icon, user: user, keyword: "b")
    expect(user.galleryless_icons).to eq([icon1, icon2, icon3, icon4])
  end

  describe "blocking" do
    it "correctly catches blocked interaction users" do
      blocker = create(:user)
      unblocked = create(:user)
      only_posts = create(:user)
      create(:block, blocking_user: blocker, blocked_user: only_posts, hide_them: Block::POSTS, block_interactions: false)
      blockees = create_list(:user, 3)
      blockees.each { |b| create(:block, blocking_user: blocker, blocked_user: b, block_interactions: true) }
      expect(blocker.can_interact_with?(unblocked)).to be(true)
      expect(blocker.can_interact_with?(only_posts)).to be(true)
      expect(blocker.can_interact_with?(blockees.first)).to be(false)
      expect(blocker.user_ids_uninteractable).to match_array(blockees.map(&:id))
      expect(blocker).not_to have_interaction_blocked(only_posts)
      expect(blocker).to have_interaction_blocked(blockees.first)
    end

    describe "content" do
      let(:user) { create(:user) }
      let(:blocking_post_user) { create(:user) }
      let(:blocking_content_user) { create(:user) }
      let(:blocked_post_user) { create(:user) }
      let(:blocked_content_user) { create(:user) }
      let(:irrelevant_blocker1) { create(:user) }
      let(:irrelevant_blocker2) { create(:user) }

      before(:each) {
        create(:block, blocking_user: blocking_post_user, blocked_user: user, hide_me: Block::POSTS)
        create(:block, blocking_user: blocking_content_user, blocked_user: user, hide_me: Block::ALL)
        create(:block, blocking_user: user, blocked_user: blocked_post_user, hide_them: Block::POSTS)
        create(:block, blocking_user: user, blocked_user: blocked_content_user, hide_them: Block::ALL)
        create(:block, blocking_user: irrelevant_blocker1, blocked_user: user, block_interactions: true)
        create(:block, blocking_user: irrelevant_blocker2, blocked_user: user, hide_them: Block::POSTS)
      }

      it "correctly handles all hidden post users" do
        expect(user.hidden_post_users).to match_array([blocking_post_user, blocking_content_user, blocked_post_user, blocked_content_user].map(&:id))
      end

      it "correctly handles just blocking post users" do
        expect(user.blocking_post_users).to match_array([blocking_post_user, blocking_content_user].map(&:id))
      end
    end
  end

  describe "archive" do
    it "succeeds" do
      user = create(:user)
      user.archive
      expect(user.deleted).to be(true)
    end

    it "turns off email notifications" do
      user = create(:user)
      user.update!(email_notifications: true)
      user.archive
      expect(user.deleted).to be(true)
      expect(user.email_notifications).to be(false)
    end

    it "removes ownership of settings" do
      user = create(:user)
      setting = create(:setting, user: user, owned: true)
      user.archive
      expect(user.deleted).to be(true)
      expect(setting.reload.owned).to be(false)
    end

    it "does not change username when persisted" do
      user = create(:user, username: 'test')
      user.archive
      user.reload
      expect(user.send(:[], :username)).to eq('test')
    end

    it "removes related blocks" do
      user = create(:user)
      create(:block, blocking_user: user)
      create(:block, blocked_user: user)
      expect(Block.count).to be(2)
      user.archive
      expect(user.deleted).to be(true)
      expect(Block.count).to be(0)
    end
  end

  describe "visiblity caching" do
    let (:user) { create(:user) }
    let (:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

    before(:each) do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
      create(:post, privacy: Concealable::ACCESS_LIST)
      create(:post, privacy: Concealable::PRIVATE)
      create(:post)
      create(:post, user: user, privacy: Concealable::ACCESS_LIST)
      create(:post, privacy: Concealable::ACCESS_LIST, viewer_ids: [create(:user).id])
      PostViewer.create!(post: create(:post), user: create(:user))
    end

    it "handles no visible access-listed posts" do
      expect(user.visible_posts).to be_empty
    end

    context "with a visible post" do
      let (:visible_post) { create(:post, privacy: Concealable::ACCESS_LIST, viewer_ids: [user.id, create(:user).id]) }

      before(:each) { visible_post }

      it "handles one visible access-listed post" do
        expect(user.visible_posts).to eq([visible_post.id])
      end

      it "records the correct visible posts" do
        second_visible = create(:post, privacy: Concealable::ACCESS_LIST, viewer_ids: [user.id] + create_list(:user, 3).map(&:id))
        third_visible = create(:post, privacy: Concealable::ACCESS_LIST, viewer_ids: [user.id])
        expect(user.visible_posts).to match_array([visible_post.id, second_visible.id, third_visible.id])
        expect(Rails.cache.exist?(PostViewer.cache_string_for(user.id))).to be(true)
      end

      it "handles being removed from access list" do
        expect(user.visible_posts).to eq([visible_post.id])
        ids = visible_post.viewer_ids - [user.id]
        visible_post.update!(viewer_ids: ids)
        expect(PostViewer.where(user: user).pluck(:post_id)).to be_empty
        expect(Rails.cache.exist?(PostViewer.cache_string_for(user.id))).to be(false)
        expect(user.visible_posts).to be_empty
        expect(Post.visible_to(user)).not_to include(visible_post)
      end

      it "handles being added to an access list" do
        expect(user.visible_posts).to eq([visible_post.id])
        second_visible = create(:post, privacy: Concealable::ACCESS_LIST, viewer_ids: create_list(:user, 3).map(&:id))
        ids = second_visible.viewer_ids + [user.id]
        second_visible.update!(viewer_ids: ids)
        expect(Rails.cache.exist?(PostViewer.cache_string_for(user.id))).to be(false)
        expect(user.visible_posts).to match_array([visible_post.id, second_visible.id])
      end

      it "handles a new access-listed post" do
        expect(user.visible_posts).to eq([visible_post.id])
        expect(Rails.cache.exist?(PostViewer.cache_string_for(user.id))).to be(true)
        second_visible = create(:post, privacy: Concealable::ACCESS_LIST, viewer_ids: [user.id] + create_list(:user, 3).map(&:id))
        expect(Rails.cache.exist?(PostViewer.cache_string_for(user.id))).to be(false)
        expect(user.visible_posts).to match_array([visible_post.id, second_visible.id])
      end

      it "handles a post becoming access-listed" do
        public_post = create(:post)
        public_post.update!(privacy: Concealable::ACCESS_LIST, viewer_ids: [user.id])
        expect(Post.visible_to(user)).to include(visible_post)
      end

      it "handles a post becoming access-listed with existing PostViewer" do
        public_post = create(:post)
        PostViewer.create!(post: public_post, user: user)
        expect(user.visible_posts).to match_array([visible_post.id, public_post.id])
        public_post.update!(privacy: Concealable::ACCESS_LIST)
        expect(Post.visible_to(user)).to include(visible_post)
      end

      it "handles an access listed post becoming public" do
        expect(user.visible_posts).to eq([visible_post.id])
        expect(Rails.cache.exist?(PostViewer.cache_string_for(user.id))).to be(true)
        visible_post.update!(privacy: Concealable::PUBLIC)
        expect(Post.all.visible_to(user)).to include(visible_post)
      end

      it "handles an access listed post becoming private" do
        expect(user.visible_posts).to eq([visible_post.id])
        expect(Post.visible_to(user)).to include(visible_post)
        visible_post.update!(privacy: Concealable::PRIVATE)
        expect(Post.visible_to(user)).not_to include(visible_post)
      end
    end
  end
end
