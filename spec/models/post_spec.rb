RSpec.describe Post do
  describe "timestamps" do
    let!(:post) { create(:post) }
    let!(:old_edited_at) { post.edited_at }
    let!(:time) { post.edited_at + 1.hour }

    it "should be correct on creation" do
      expect(post.edited_at).to be_the_same_time_as(post.created_at)
      expect(post.tagged_at).to be_the_same_time_as(post.created_at)
    end

    describe "with no replies" do
      let!(:old_tagged_at) { post.tagged_at }

      it "should update edited_at and tagged_at when edited" do
        Timecop.freeze(time) do
          post.update!(content: 'new content')
        end
        expect(post.tagged_at).to be_the_same_time_as(post.edited_at)
        expect(post.tagged_at).to be > post.created_at
      end

      it "should update edited_at and tagged_at when status edited" do
        Timecop.freeze(time) do
          post.update!(status: :complete)
        end
        expect(post.tagged_at).to be > old_tagged_at
        expect(post.edited_at).to be > old_edited_at
      end

      it "should not update with invalid edit" do
        Timecop.freeze(time) do
          post.update!(section_order: post.section_order + 1)
        end
        expect(post.tagged_at).to be_the_same_time_as(old_tagged_at)
        expect(post.edited_at).to be_the_same_time_as(old_edited_at)
      end
    end

    it "should update tagged_at but not edited_at when reply created" do
      reply = Timecop.freeze(time) do
        create(:reply, post: post)
      end
      post.reload
      expect(post.tagged_at).to be_the_same_time_as(reply.created_at)
      expect(post.edited_at).to be_the_same_time_as(old_edited_at)
      expect(post.tagged_at).to be > post.edited_at
    end

    describe "with replies" do
      let!(:reply) do
        Timecop.freeze(post.edited_at + 15.minutes) { create(:reply, post: post) }
      end
      let!(:old_tagged_at) { post.tagged_at }

      it "should update edited_at but not tagged_at when subject edited" do
        Timecop.freeze(time) do
          post.update!(subject: 'new title')
        end
        expect(post.edited_at).to be > post.created_at
        expect(post.tagged_at).to be_the_same_time_as(old_tagged_at)
      end

      it "should update edited_at but not tagged_at when content edited" do
        Timecop.freeze(time) do
          post.update!(content: 'newer content')
        end
        expect(post.tagged_at).to be_the_same_time_as(old_tagged_at)
        expect(post.edited_at).to be > old_edited_at
      end

      it "should update edited_at and tagged_at when status edited" do
        Timecop.freeze(time) do
          post.update!(status: :complete)
        end
        expect(post.tagged_at).to be > old_tagged_at
        expect(post.edited_at).to be > old_edited_at
      end

      it "should not update on invalid edit" do
        Timecop.freeze(time) do
          post.update!(section_order: post.section_order + 1)
        end
        expect(post.tagged_at).to be_the_same_time_as(old_tagged_at)
        expect(post.edited_at).to be_the_same_time_as(old_edited_at)
      end

      it "should update tagged_at but not edited_at with a second reply" do
        reply2 = Timecop.freeze(time) do
          create(:reply, post: post)
        end
        post.reload
        expect(reply2.reply_order).to eq(1)
        expect(post.tagged_at).to be_the_same_time_as(reply2.created_at)
        expect(post.updated_at).to be_the_same_time_as(reply2.created_at)
        expect(post.tagged_at).to be > post.edited_at
      end

      describe "two" do
        let!(:reply2) do
          Timecop.freeze(post.edited_at + 30.minutes) { create(:reply, post: post) }
        end
        let!(:old_tagged_at) { post.tagged_at } # rubocop:disable RSpec/LetSetup # false positive

        it "should not update if first reply edited" do
          old_tagged_at = post.tagged_at
          Timecop.freeze(time) do
            reply.update!(content: 'new content')
          end
          post.reload
          expect(post.tagged_at).to be_the_same_time_as(old_tagged_at)
          expect(post.edited_at).to be_the_same_time_as(old_edited_at)
        end

        it "should update tagged_at but not edited_at if second reply edited" do
          Timecop.freeze(time) do
            reply2.update!(content: 'new content')
          end
          post.reload
          expect(post.tagged_at).to be_the_same_time_as(reply2.updated_at)
          expect(post.edited_at).to be_the_same_time_as(old_edited_at)
        end
      end
    end
  end

  describe "#destroy" do
    it "should delete views" do
      post = create(:post)
      user = create(:user)
      expect(Post::View.count).to be_zero
      post.mark_read(user)
      expect(Post::View.count).not_to be_zero
      post.destroy!
      expect(Post::View.count).to be_zero
    end
  end

  describe "#edited_at" do
    let(:post) { create(:post) }

    it "should update when a field is changed" do
      expect(post.edited_at).to eq(post.created_at)
      post.update!(content: 'new content now')
      expect(post.edited_at).not_to eq(post.created_at)
    end

    it "should update when multiple fields are changed" do
      expect(post.edited_at).to eq(post.created_at)
      post.update!(subject: 'new subject', description: 'description')
      expect(post.edited_at).not_to eq(post.created_at)
    end

    it "should not update when skip is set" do
      expect(post.edited_at).to eq(post.created_at)
      post.skip_edited = true
      post.touch # rubocop:disable Rails/SkipsModelValidations
      expect(post.edited_at).to eq(post.created_at)
    end

    it "should not update when a reply is made" do
      expect(post.edited_at).to eq(post.created_at)
      create(:reply, post: post, user: post.user)
      expect(post.edited_at).to eq(post.created_at)
    end

    it "should update correctly when characters are edited" do
      Post.auditing_enabled = true
      time = Time.zone.now
      post = Timecop.freeze(time - 5.minutes) do
        create(:post)
      end
      expect(post.edited_at).to be_the_same_time_as(time - 5.minutes)
      expect(post.updated_at).to be_the_same_time_as(time - 5.minutes)
      expect(post.audits.count).to eq(1)

      Timecop.freeze(time) do
        post.update!(character: create(:character, user: post.user))
      end

      # editing a post's character changes edit and makes audit but does not tag
      expect(post.edited_at).to be_the_same_time_as(time)
      expect(post.audits.count).to eq(2)
      expect(post.tagged_at).to be_the_same_time_as(time - 5.minutes)
      Post.auditing_enabled = false
    end
  end

  describe "#section_order" do
    let(:board) { create(:board) }
    let(:section) { create(:board_section, board: board) }

    it "should be set on create" do
      posts = create_list(:post, 5, board: board)
      expect(posts.map(&:section_order)).to eq([0, 1, 2, 3, 4])
    end

    it "should be set in its section on create" do
      posts = create_list(:post, 5, board: board, section: section)
      expect(posts.map(&:section_order)).to eq([0, 1, 2, 3, 4])
    end

    it "should handle mix and match section/no section creates" do
      expect(section.section_order).to eq(0)
      posts = create_list(:post, 5, board: board, section: section)
      expect(posts.map(&:section_order)).to eq([0, 1, 2, 3, 4])

      posts2 = create_list(:post, 2, board: board)
      expect(posts2.map(&:section_order)).to eq([0, 1])

      post = create(:post, board_id: board.id, section_id: section.id)
      expect(post.section_order).to eq(5)

      section = create(:board_section, board: board)
      expect(section.section_order).to eq(1)

      sectionless_post = create(:post, board: board)
      expect(sectionless_post.section_order).to eq(2)

      board.board_sections.ordered.each_with_index do |s, i|
        expect(s.section_order).to eq(i)
      end

      board.posts.where(section_id: nil).ordered_in_section.each_with_index do |s, i|
        expect(s.section_order).to eq(i)
      end

      section.posts.ordered_in_section.each_with_index do |s, i|
        expect(s.section_order).to eq(i)
      end
    end

    it "should update when section is changed" do
      posts = create_list(:post, 3, board: board, section: section)
      expect(posts.map(&:section_order)).to eq([0, 1, 2])
      section = create(:board_section, board: board)
      posts[1].update!(section: section)
      expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
    end

    it "should update when board is changed" do
      create_list(:post, 2, board: board)
      post = create(:post, board: board)
      expect(post.section_order).to eq(2)
      post.update!(board: create(:board))
      post.reload
      expect(post.section_order).to eq(0)
    end

    it "should not increment on non-section update" do
      post = create(:post, board: board)
      expect(post.section_order).to eq(0)
      create_list(:post, 2, board: board)
      post.update!(content: 'new content')
      post.reload
      expect(post.section_order).to eq(0)
    end

    it "should reorder upon deletion" do
      board = create(:board, authors_locked: true)
      posts = create_list(:post, 4, board: board, user: board.creator)
      expect(posts.map(&:section_order)).to eq([0, 1, 2, 3])
      posts[1].destroy!
      expect(posts.map{|p| Post.find_by(id: p.id)&.section_order}).to eq([0, nil, 1, 2])
    end

    it "should reorder upon board change" do
      board = create(:board, authors_locked: true)
      posts = create_list(:post, 4, board: board, user: board.creator)
      expect(posts.map(&:section_order)).to eq([0, 1, 2, 3])
      posts[1].update!(board: create(:board))
      expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1, 2])
    end

    it "should autofill correctly upon board change" do
      board2 = create(:board)
      posts = create_list(:post, 2, board: board)
      post = create(:post, board: board2)
      expect(posts.map(&:section_order)).to eq([0, 1])
      expect(post.section_order).to eq(0)

      post.update!(board: board, skip_edited: true)
      expect(posts.map(&:section_order)).to eq([0, 1])
      expect(post.section_order).to eq(2)
    end

    it "should autofill correctly upon board change with mix" do
      board2 = create(:board)

      section1 = create(:board_section, board: board)
      post = create(:post, board: board)
      section2 = create(:board_section, board: board)

      expect(section1.section_order).to eq(0)
      expect(post.section_order).to eq(0)
      expect(section2.section_order).to eq(1)

      post.update!(board: board2, skip_edited: true)

      expect(post.reload.section_order).to eq(0)
      expect(section1.reload.section_order).to eq(0)
      expect(section2.reload.section_order).to eq(1)
    end
  end

  describe "#has_icons?" do
    let(:user) { create(:user) }

    context "without character" do
      let(:post) { create(:post, user: user) }

      it "is true with avatar" do
        icon = create(:icon, user: user)
        user.update!(avatar: icon)
        user.reload

        expect(post.character).to be_nil
        expect(post.has_icons?).to eq(true)
      end

      it "is false without avatar" do
        expect(post.character).to be_nil
        expect(post.has_icons?).not_to eq(true)
      end
    end

    context "with character" do
      let(:character) { create(:character, user: user) }
      let(:post) { create(:post, user: user, character: character) }

      it "is true with default icon" do
        icon = create(:icon, user: user)
        character.update!(default_icon: icon)
        expect(post.has_icons?).to eq(true)
      end

      it "is false without galleries" do
        expect(post.has_icons?).not_to eq(true)
      end

      it "is true with icons in galleries" do
        gallery = create(:gallery, user: user)
        gallery.icons << create(:icon, user: user)
        character.galleries << gallery
        expect(post.has_icons?).to eq(true)
      end

      it "is false without icons in galleries" do
        character.galleries << create(:gallery, user: user)
        expect(post.has_icons?).not_to eq(true)
      end
    end
  end

  describe "validations" do
    let(:post) { build(:post) }

    it "should work" do
      expect(post).to be_valid
    end

    it "requires user" do
      post.user = nil
      expect(post).not_to be_valid
    end

    it "requires user's character" do
      post.character = create(:character)
      expect(post).not_to be_valid
    end

    it "requires user's icon" do
      post.icon = create(:icon)
      expect(post).not_to be_valid
    end

    it "requires board the user can access" do
      post.board = create(:board, authors_locked: true)
      expect(post).not_to be_valid
    end

    it "requires board section matching board" do
      post.section = create(:board_section)
      expect(post).not_to be_valid
    end

    it "should allow blank content" do
      post.content = ''
      expect(post).to be_valid
      expect(post.save).to be(true)
    end
  end

  describe "#word_count" do
    it "guesses correctly with replies" do
      post = create(:post, content: 'one two three four five')
      create(:reply, post: post, content: 'six seven')
      create(:reply, post: post, content: 'eight')
      expect(post.word_count).to eq(5)
      expect(post.total_word_count).to eq(8)
    end

    it "guesses correctly without replies" do
      post = create(:post, content: 'one two three four five')
      expect(post.word_count).to eq(5)
      expect(post.total_word_count).to eq(5)
    end

    it "orders users correctly" do
      post = create(:post, content: 'one')
      two = create(:reply, post: post, content: 'two two')
      three = create(:reply, post: post, content: 'three three three')
      post = Post.find(post.id) # authors get cached
      counts = post.author_word_counts
      expect(counts[0][0]).to eq(three.user.username)
      expect(counts[0][1]).to eq(3)
      expect(counts[1][0]).to eq(two.user.username)
      expect(counts[1][1]).to eq(2)
      expect(counts[2][0]).to eq(post.user.username)
      expect(counts[2][1]).to eq(1)
    end

    it "handles never posted users" do
      post = create(:post)
      expect(post.word_count_for(create(:user))).to eq(0)
    end

    it "handles posted no replies" do
      post = create(:post, content: 'a a a a')
      expect(post.word_count_for(post.user)).to eq(4)
    end

    it "handles posted + replies" do
      post = create(:post, content: 'a a a a')
      create(:reply, user: post.user, post: post, content: 'a a a')
      create(:reply, post: post, user: post.user, content: 'a a')
      create(:reply, post: post, content: 'c')
      expect(post.word_count_for(post.user)).to eq(9)
    end

    it "handles only replies" do
      post = create(:post, content: 'a a a a')
      reply = create(:reply, post: post, content: 'b b b')
      create(:reply, post: post, user: reply.user, content: 'b b')
      create(:reply, post: post, content: 'c')
      expect(post.word_count_for(reply.user)).to eq(5)
    end
  end

  describe "#visible_to?" do
    context "public" do
      let(:post) { create(:post, privacy: :public) }

      it "is visible to poster" do
        expect(post).to be_visible_to(post.user)
      end

      it "is visible to author" do
        reply = create(:reply, post: post)
        expect(post).to be_visible_to(reply.user)
      end

      it "is visible to site user" do
        expect(post).to be_visible_to(create(:user))
      end

      it "is visible to logged out users" do
        expect(post).to be_visible_to(nil)
      end
    end

    context "private" do
      let(:post) { create(:post, privacy: :private) }

      it "is visible to poster" do
        expect(post).to be_visible_to(post.user)
      end

      it "is not visible to author" do # TODO seems wrong
        reply = create(:reply, post: post)
        expect(post).not_to be_visible_to(reply.user)
      end

      it "is not visible to site user" do
        expect(post).not_to be_visible_to(create(:user))
      end

      it "is not visible to logged out users" do
        expect(post).not_to be_visible_to(nil)
      end
    end

    context "list" do
      let(:post) { create(:post, privacy: :access_list) }

      it "is visible to poster" do
        expect(post).to be_visible_to(post.user)
      end

      it "is visible to list user" do
        user = create(:user)
        post.viewers << user
        expect(post.reload).to be_visible_to(user)
      end

      it "is not visible to author" do # TODO seems wrong
        reply = create(:reply, post: post)
        expect(post).not_to be_visible_to(reply.user)
      end

      it "is not visible to site user" do
        expect(post).not_to be_visible_to(create(:user))
      end

      it "is not visible to logged out users" do
        expect(post).not_to be_visible_to(nil)
      end
    end

    context "registered" do
      let(:post) { create(:post, privacy: :registered) }

      it "is visible to poster" do
        expect(post).to be_visible_to(post.user)
      end

      it "is visible to author" do
        reply = create(:reply, post: post)
        expect(post).to be_visible_to(reply.user)
      end

      it "is visible to arbitrary site user" do
        expect(post).to be_visible_to(create(:user))
      end

      it "is not visible to logged out (nil) users" do
        expect(post).not_to be_visible_to(nil)
      end
    end

    context "blocks" do
      it "hides blocked posts" do
        post = create(:post, authors_locked: true)
        block = create(:block, blocking_user: post.user, hide_me: :posts)
        expect(post.reload).not_to be_visible_to(block.blocked_user)
      end

      it "does not hide blocked users (so you can use show_blocked param)" do
        post = create(:post, authors_locked: true)
        block = create(:block, blocked_user: post.user, hide_them: :posts)
        expect(post.reload).to be_visible_to(block.blocking_user)
      end

      it "does not hide coauthored posts when blocked" do
        coauthor = create(:user)
        post = create(:post, authors_locked: true, author_ids: [coauthor.id])
        create(:reply, post: post, user: coauthor)
        create(:block, blocking_user: post.user, blocked_user: coauthor, hide_me: :posts)
        expect(post.reload).to be_visible_to(coauthor)
      end
    end
  end

  describe "#first_unread_for" do
    let(:user) { create(:user) }
    let(:post) { create(:post, user: user) }

    it "uses instance variable if set" do
      post.instance_variable_set('@first_unread', 3)
      expect(post).not_to receive(:last_read)
      expect(post.first_unread_for(nil)).to eq(3)
    end

    it "uses itself if not yet viewed" do
      create(:reply, post: post)
      expect(post.first_unread_for(post)).to eq(post)
    end

    context "with replies" do
      before(:each) { create(:reply, post: post) }

      it "uses nil if full post viewed" do
        post.mark_read(user)
        expect(post.first_unread_for(user)).to be_nil
      end

      it "uses nil if full continuity viewed" do
        post.board.mark_read(user)
        expect(post.first_unread_for(user)).to be_nil
      end

      it "uses reply created after viewed_at if partially viewed" do
        post.mark_read(user)
        unread = create(:reply, post: post)
        expect(post.first_unread_for(user)).to eq(unread)
      end

      it "handles status changes" do
        Post.auditing_enabled = true
        post.mark_read(user)
        unread = create(:reply, post: post)
        expect(post.first_unread_for(user)).to eq(unread)
        expect(post.read_time_for(post.replies)).to be_the_same_time_as(unread.created_at)

        Timecop.freeze(unread.created_at + 1.day) do
          post.update!(status: :complete)

          post.description = 'new description to add another audit'
          post.save!
        end

        post.reload
        expect(post.edited_at).to be > unread.updated_at
        expect(post.first_unread_for(user)).to eq(unread)
        expect(post.read_time_for(post.replies)).to be_the_same_time_as(post.edited_at)
        Post.auditing_enabled = false
      end
    end

    context "without replies" do
      it "uses nil if post viewed" do
        post.mark_read(user)
        expect(post.first_unread_for(user)).to be_nil
      end

      it "uses nil if continuity viewed" do
        post.board.mark_read(user)
        expect(post.first_unread_for(user)).to be_nil
      end
    end
  end

  describe "#recent_characters_for" do
    let(:user) { create(:user) }
    let(:char) { create(:character, user: user)}
    let(:post) { create(:post, user: user, character: char) }

    it "is blank if user has not responded to post" do
      post = create(:post)
      create(:reply, post: post)
      expect(post.authors).not_to include(user)
      expect(post.recent_characters_for(user, 4)).to be_blank
    end

    it "includes the post character if relevant" do
      expect(post.recent_characters_for(user, 4)).to match_array([char])
    end

    it "only includes characters for specified author" do
      other_char = create(:character)
      create(:reply, post: post, user: other_char.user, character: other_char)
      reply = create(:reply, character_id: nil)
      expect(post.recent_characters_for(reply.user, 4)).to be_blank
    end

    it "returns correctly ordered information without duplicates" do
      reply_char = create(:character, user: user)
      reply_char2 = create(:character, user: user)
      create(:reply, post: post, user: user, character: reply_char)
      create(:reply, post: post, user: user, character: reply_char)
      create(:reply, post: post, user: user, character: char)
      create(:reply, post: post, user: user, character: reply_char2)
      coauthor = create(:user)
      cochar = create(:character, user: coauthor)
      create(:reply, post: post, user: coauthor, character: cochar)

      other_char = create(:character, user: user)
      other_post = create(:post, user: user, character: other_char)
      create(:reply, post: other_post, user: user, character: other_char)
      create(:reply, post: post, user: coauthor, character: cochar)

      expect(post.recent_characters_for(user, 4)).to eq([reply_char2, char, reply_char])
    end

    it "limits the amount of returned data" do
      characters = create_list(:character, 10, user: user)
      post_char = create(:character, user: user)
      post = create(:post, user: user, character: post_char)
      characters.each do |char|
        create(:reply, user: user, post: post, character: char)
      end

      expect(post.recent_characters_for(user, 9)).to eq(characters[-9..-1].reverse)
      expect(post.recent_characters_for(user, 10)).to eq(characters.reverse)
    end
  end

  describe "#reset_warnings" do
    let(:post) { create(:post) }
    let(:warning) { create(:content_warning) }
    let(:user) { create(:user) }

    before(:each) do
      post.content_warnings << warning
      post.hide_warnings_for(user)
    end

    it "does not reset on update" do
      post.update!(description: 'new description')
      expect(post.reload).not_to be_show_warnings_for(user)
    end

    it "does not reset on remove" do
      post.content_warnings.delete(warning)
      expect(post.reload).not_to be_show_warnings_for(user)
    end

    it "resets with new warning without changing read time" do
      at_time = 3.days.ago
      post.mark_read(user, at_time: at_time, force: true)
      post.content_warnings << create(:content_warning)
      expect(post.reload).to be_show_warnings_for(user)
      expect(post.last_read(user)).to be_the_same_time_as(at_time)
    end
  end

  describe "#build_new_reply_for" do
    let(:post) { create(:post) }
    let(:user) { create(:user) }
    let(:icon) { create(:icon, user: user) }

    it "uses a draft if one exists" do
      draft = create(:reply_draft, post: post)
      reply = post.build_new_reply_for(draft.user)
      expect(reply).to be_a_new_record
      expect(reply.user).to eq(draft.user)
      expect(reply.content).to eq(draft.content)
    end

    it "copies most recent reply details if present" do
      last_reply = create(:reply, post: post, user: user, with_character: true, with_icon: true)
      last_reply.character.update!(default_icon: create(:icon, user: user))
      last_reply.reload
      reply = post.build_new_reply_for(user)
      expect(reply).to be_a_new_record
      expect(reply.user).to eq(user)
      expect(reply.icon_id).to eq(last_reply.character.default_icon_id)
      expect(reply.character_id).to eq(last_reply.character_id)
    end

    it "copies post details if it belongs to the user" do
      post = create(:post, user: user, with_character: true, with_icon: true)
      reply = post.build_new_reply_for(user)
      expect(reply).to be_a_new_record
      expect(reply.user).to eq(user)
      expect(reply.icon_id).to eq(post.character.default_icon_id)
      expect(reply.character_id).to eq(post.character_id)
    end

    it "uses active character if available" do
      character = create(:character, user: user, with_default_icon: true)
      user.update!(active_character: character)

      reply = post.build_new_reply_for(user)

      expect(reply).to be_a_new_record
      expect(reply.user).to eq(user)
      expect(reply.icon_id).to eq(character.default_icon_id)
      expect(reply.character_id).to eq(character.id)
    end

    it "does not use avatar for active character without icons" do
      character = create(:character, user: user)
      user.update!(avatar: icon, active_character: character)

      reply = post.build_new_reply_for(user)

      expect(reply).to be_a_new_record
      expect(reply.user).to eq(user)
      expect(reply.icon_id).to be_nil
      expect(reply.character_id).to eq(character.id)
    end

    it "uses avatar if available" do
      user.update!(avatar: icon)

      reply = post.build_new_reply_for(user)

      expect(reply).to be_a_new_record
      expect(reply.user).to eq(user)
      expect(reply.icon_id).to eq(user.avatar_id)
      expect(reply.character_id).to be_nil
    end

    it "handles new user" do
      reply = post.build_new_reply_for(user)

      expect(reply).to be_a_new_record
      expect(reply.user).to eq(user)
      expect(reply.icon_id).to be_nil
      expect(reply.character_id).to be_nil
    end
  end

  describe "last_user_deleted" do
    let(:user) { create(:user) }
    let(:post) { create(:post, user: user) }

    it "loads from the database if not loaded via select" do
      user.archive
      expect(post.reload.last_user_deleted?).to eq(true)
    end

    it "reads from attribute if loaded via select" do
      relation = Post.where(id: post.id).joins(:last_user).select('posts.*, users.deleted as last_user_deleted').first
      user.archive
      expect(relation.last_user_deleted?).to eq(false) # not reloaded loads cached false
    end
  end

  describe "#has_content_warnings?" do
    let(:warning) { create(:content_warning) }
    let(:post) { create(:post, content_warnings: [warning]) }

    it "is false with no warnings" do
      expect(create(:post).has_content_warnings?).to be(false)
    end

    it "is true with warnings" do
      expect(post.has_content_warnings?).to be(true)
    end

    it "is true with preloaded warnings" do
      relation = Post.where(id: post.id).with_has_content_warnings.first
      expect(relation.has_content_warnings?).to be(true)
    end
  end

  describe "authors" do
    it "automatically creates an author on creation" do
      post = create(:post)
      expect(post.authors).to eq([post.user])
      author = post.post_authors.first
      expect(author.joined).to eq(true)
      expect(author.joined_at).to be_the_same_time_as(post.created_at)
    end

    it "invites coauthors on creation" do
      invited = create(:user)
      post = create(:post, unjoined_author_ids: [invited.id])
      expect(post.authors).to match_array([post.user, invited])
      invited_author = post.author_for(invited)
      expect(invited_author.can_owe).to be(true)
      expect(invited_author.joined).to be(false)
    end

    it "automatically adds to (joined) authors upon reply" do
      post = create(:post)
      expect(post.authors).to eq([post.user])
      reply = create(:reply, post: post)
      expect(post.authors.reload).to match_array([post.user, reply.user])
      expect(post.authors.count).to eq(post.joined_authors.count)
    end
  end

  describe "#opt_out_of_owed" do
    it "removes owedness if user previously could owe" do
      post = create(:post)
      author = post.author_for(post.user)
      expect(author.reload.can_owe).to eq(true)
      post.opt_out_of_owed(post.user)
      expect(author.reload.can_owe).to eq(false)
    end

    it "destroys if not joined" do
      user = create(:user)
      post = create(:post, unjoined_authors: [user])
      author = post.author_for(user)
      expect(author.reload.can_owe).to eq(true)
      post.opt_out_of_owed(user)
      expect(Post::Author.find_by(id: author.id)).to be_nil
    end
  end

  describe "#taggable_by" do
    let(:poster) { create(:user) }
    let(:coauthor) { create(:user) }

    shared_examples "common taggable tests" do
      it "should allow post creator" do
        expect(post).to be_taggable_by(poster)
      end

      it "should allow invited coauthors" do
        expect(post).to be_taggable_by(coauthor)
      end

      it "should allow joined coauthors" do
        create(:reply, user: coauthor, post: post)
        expect(post).to be_taggable_by(coauthor)
      end

      it "should allow coauthors who have opted out of owing" do
        create(:reply, user: coauthor, post: post)
        post.opt_out_of_owed(coauthor)
        expect(post).to be_taggable_by(coauthor)
      end
    end

    context "with open post" do
      let(:post) { create(:post, user: poster, joined_authors: [poster], unjoined_authors: [coauthor], authors_locked: false) }

      include_examples "common taggable tests"

      it "should allow non-authors to reply" do
        expect(post).to be_taggable_by(create(:user))
      end
    end

    context "with closed post" do
      let(:post) { create(:post, user: poster, joined_authors: [poster], unjoined_authors: [coauthor], authors_locked: true) }

      include_examples "common taggable tests"

      it "should not allow non-authors" do
        expect(post).not_to be_taggable_by(create(:user))
      end

      it "should not allow removed couathors" do
        skip "TODO Not currently implemented"
      end
    end
  end

  describe "#visible_to" do
    it "logged out only shows public posts" do
      create(:post, privacy: :private)
      create_list(:post, 2, privacy: :access_list)
      create_list(:post, 2, privacy: :registered)
      posts = create_list(:post, 3, privacy: :public)
      expect(Post.visible_to(nil)).to match_array(posts)
    end

    describe "logged in" do
      let(:user) { create(:user) }

      it "shows constellation-only posts" do
        posts = create_list(:post, 2, privacy: :registered)
        expect(Post.visible_to(user)).to match_array(posts)
      end

      it "shows own access-listed posts" do
        posts = create_list(:post, 2, privacy: :access_list, user: user)
        expect(Post.visible_to(user)).to match_array(posts)
      end

      it "shows access-listed posts with access" do
        post = create(:post, privacy: :access_list, viewers: [user])
        expect(Post.visible_to(user)).to eq([post])
      end

      it "does not show other access-listed posts" do
        create_list(:post, 2, privacy: :access_list)
        expect(Post.visible_to(user)).to be_empty
      end

      it "shows own private posts" do
        posts = create_list(:post, 2, privacy: :private, user: user)
        expect(Post.visible_to(user)).to match_array(posts)
      end

      it "does not show other private posts" do
        create_list(:post, 2, privacy: :private)
        expect(Post.visible_to(user)).to be_empty
      end
    end
  end

  describe "adjacent posts" do
    let(:user) { create(:user) }
    let(:board) { create(:board, creator: user) }
    let(:section) { create(:board_section, board: board) }

    it "gives correct next and previous posts" do
      create(:post, user: user, board: board, section: section)
      prev = create(:post, user: user, board: board, section: section)
      post = create(:post, user: user, board: board, section: section)
      nextp = create(:post, user: user, board: board, section: section)
      create(:post, user: user, board: board, section: section)
      expect([prev, post, nextp].map(&:section_order)).to eq([1, 2, 3])

      expect(post.prev_post(user)).to eq(prev)
      expect(post.next_post(user)).to eq(nextp)
    end

    it "gives the correct previous post with an intermediate private post" do
      extra = create(:post, user: user, board: board, section: section)
      prev = create(:post, user: user, board: board, section: section)
      hidden = create(:post, board: board, section: section, privacy: :private)
      post = create(:post, user: user, board: board, section: section)
      expect([extra, prev, hidden, post].map(&:section_order)).to eq([0, 1, 2, 3])

      expect(post.prev_post(user)).to eq(prev)
      expect(post.next_post(user)).to be_nil
    end

    it "gives the correct next post with an intermediate private post" do
      post = create(:post, user: user, board: board, section: section)
      hidden = create(:post, board: board, section: section, privacy: :private)
      nextp = create(:post, user: user, board: board, section: section)
      extra = create(:post, user: user, board: board, section: section)
      expect([post, hidden, nextp, extra].map(&:section_order)).to eq([0, 1, 2, 3])

      expect(post.next_post(user)).to eq(nextp)
      expect(post.prev_post(user)).to be_nil
    end

    it "does not give previous with only a non-visible post in section" do
      hidden = create(:post, board: board, section: section, privacy: :private)
      post = create(:post, user: user, board: board, section: section)
      hidden.update!(section_order: 0)
      post.update!(section_order: 1)

      expect(post.prev_post(user)).to be_nil
    end

    it "does not give next with only a non-visible post in section" do
      post = create(:post, user: user, board: board, section: section)
      hidden = create(:post, board: board, section: section, privacy: :private)
      post.update!(section_order: 0)
      hidden.update!(section_order: 1)

      expect(post.next_post(user)).to be_nil
    end

    it "handles very large mostly-hidden sections as expected" do
      prev = create(:post, user: user, board: board, section: section)
      create_list(:post, 10, board: board, section: section, privacy: :private)
      post = create(:post, user: user, board: board, section: section)
      create_list(:post, 10, board: board, section: section, privacy: :private)
      nextp = create(:post, user: user, board: board, section: section)

      expect(post.prev_post(user)).to eq(prev)
      expect(post.next_post(user)).to eq(nextp)
    end

    it "does not give next or previous on unordered boards" do
      create(:post, board: board)
      post = create(:post, board: board)
      create(:post, board: board)

      expect(post.prev_post(user)).to be_nil
      expect(post.next_post(user)).to be_nil
    end

    it "handles sectionless on sectioned boards correctly" do
      section

      create(:post, user: user, board: board)
      post = create(:post, user: user, board: board)
      create(:post, user: user, board: board)

      expect(post.prev_post(user)).to be_nil
      expect(post.next_post(user)).to be_nil
    end

    it "handles ordered boards with no sections correctly" do
      board.update!(authors_locked: true)
      prev = create(:post, user: user, board: board)
      post = create(:post, user: user, board: board)
      nextp = create(:post, user: user, board: board)

      expect(post.prev_post(user)).to eq(prev)
      expect(post.next_post(user)).to eq(nextp)
    end

    it "handles first post and last posts in section" do
      first = create(:post, user: user, board: board, section: section)
      create_list(:post, 3, user: user, board: board, section: section)
      last = create(:post, user: user, board: board, section: section)

      expect(first.prev_post(user)).to be_nil
      expect(last.next_post(user)).to be_nil
    end
  end

  context "callbacks" do
    include ActiveJob::TestHelper
    let(:author) { create(:user) }
    let(:notified) { create(:user) }
    let(:post) { create(:post, user: author) }

    before(:each) do
      clear_enqueued_jobs
      create(:favorite, user: notified, favorite: author)
      post
    end

    it "should enqueue a message after creation" do
      expect(NotifyFollowersOfNewPostJob).to have_been_enqueued.with(post.id, post.user_id).on_queue('notifier')
    end

    it "should only enqueue a message on authors' first join" do
      # first post triggers job
      expect(NotifyFollowersOfNewPostJob).to have_been_enqueued.with(post.id, post.user_id).on_queue('notifier')

      # original author posting again does not trigger job
      expect {
        create(:reply, post: post, user: author)
      }.not_to enqueue_job(NotifyFollowersOfNewPostJob)

      # new author posting triggers job
      new_author = create(:user)
      expect {
        create(:reply, post: post, user: new_author)
      }.to enqueue_job(NotifyFollowersOfNewPostJob)

      # further posts don't trigger
      expect {
        create(:reply, post: post, user: author)
        create(:reply, post: post, user: new_author)
      }.not_to enqueue_job(NotifyFollowersOfNewPostJob)
    end
  end
end
