RSpec.describe WritableHelper do
  describe "#shortened_desc" do
    it "uses full string if short enough" do
      text = 'a' * 100
      expect(helper.shortened_desc(text, 1)).to eq(text)
    end

    it "uses 255 chars if single long paragraph" do
      text = 'a' * 300
      more = '<a href="#" id="expanddesc-1" class="expanddesc">more &raquo;</a>'
      dots = '<span id="dots-1">... </span>'
      expand = "<span class=\"hidden\" id=\"desc-1\">#{'a' * 45}</span>"
      expect(helper.shortened_desc(text, 1)).to eq('a' * 255 + dots + expand + more)
    end
  end

  describe "#anchored_continuity_path" do
    it "anchors for sectioned post" do
      section = create(:board_section)
      post = create(:post, board: section.board, section: section)
      expect(helper.anchored_continuity_path(post)).to eq("#{continuity_path(post.board_id)}#section-#{section.id}")
    end

    it "does not anchor for unsectioned post" do
      post = create(:post)
      expect(helper.anchored_continuity_path(post)).to eq(continuity_path(post.board_id))
    end
  end

  describe "#author_links" do
    context "with only deleted users" do
      it "handles only a deleted user" do
        post = create(:post)
        post.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq('(deleted user)')
      end

      it "handles only two deleted users" do
        post = create(:post)
        post.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq('(deleted users)')
      end

      it "handles >4 deleted users" do
        post = create(:post)
        post.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq('(deleted users)')
      end
    end

    context "with active and deleted users" do
      it "handles two users with post user deleted" do
        post = create(:post)
        post.user.update!(deleted: true)
        reply = create(:reply, post: post)
        expect(helper.author_links(post)).to eq("#{helper.user_link(reply.user)} and 1 deleted user")
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles two users with reply user deleted" do
        post = create(:post)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq("#{helper.user_link(post.user)} and 1 deleted user")
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles three users with one deleted" do
        post = create(:post, user: create(:user, username: 'xxx'))
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post, user: create(:user, username: 'yyy'))
        links = [post.user, reply.user].map { |u| helper.user_link(u) }.join(', ')
        expect(helper.author_links(post)).to eq("#{links} and 1 deleted user")
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles three users with two deleted" do
        post = create(:post)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq("#{helper.user_link(post.user)} and 2 deleted users")
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles >4 users with post user first" do
        post = create(:post, user: create(:user, username: 'zzz'))
        create(:reply, post: post, user: create(:user, username: 'yyy'))
        reply = create(:reply, post: post, user: create(:user, username: 'xxx'))
        reply.user.update!(deleted: true)
        create(:reply, post: post, user: create(:user, username: 'www'))
        create(:reply, post: post, user: create(:user, username: 'vvv'))
        stats_link = helper.link_to('4 others', stats_post_path(post))
        expect(helper.author_links(post)).to eq("#{helper.user_link(post.user)} and #{stats_link}")
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles >4 users with alphabetical user first iff post user deleted" do
        post = create(:post, user: create(:user, username: 'zzz'))
        post.user.update!(deleted: true)
        create(:reply, post: post, user: create(:user, username: 'yyy'))
        create(:reply, post: post, user: create(:user, username: 'xxx'))
        reply = create(:reply, post: post, user: create(:user, username: 'aaa'))
        create(:reply, post: post, user: create(:user, username: 'vvv'))
        stats_link = helper.link_to('4 others', stats_post_path(post))
        expect(helper.author_links(post)).to eq("#{helper.user_link(reply.user)} and #{stats_link}")
        expect(helper.author_links(post)).to be_html_safe
      end
    end

    context "with only active users" do
      it "handles only one user" do
        post = create(:post)
        expect(helper.author_links(post)).to eq(helper.user_link(post.user))
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles two users with commas" do
        post = create(:post, user: create(:user, username: 'xxx'))
        reply = create(:reply, post: post, user: create(:user, username: 'yyy'))
        expect(helper.author_links(post)).to eq("#{helper.user_link(post.user)}, #{helper.user_link(reply.user)}")
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles three users with commas and no and" do
        post = create(:post, user: create(:user, username: 'zzz'))
        users = [post.user]
        users << create(:reply, post: post, user: create(:user, username: 'yyy')).user
        users << create(:reply, post: post, user: create(:user, username: 'xxx')).user
        expect(helper.author_links(post)).to eq(users.reverse.map { |u| helper.user_link(u) }.join(', '))
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles >4 users with post user first" do
        post = create(:post, user: create(:user, username: 'zzz'))
        create(:reply, post: post, user: create(:user, username: 'yyy'))
        create(:reply, post: post, user: create(:user, username: 'xxx'))
        create(:reply, post: post, user: create(:user, username: 'www'))
        create(:reply, post: post, user: create(:user, username: 'vvv'))
        stats_link = helper.link_to('4 others', stats_post_path(post))
        expect(helper.author_links(post)).to eq("#{helper.user_link(post.user)} and #{stats_link}")
        expect(helper.author_links(post)).to be_html_safe
      end
    end
  end
end
