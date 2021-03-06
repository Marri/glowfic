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
      expand = '<span class="hidden" id="desc-1">' + ('a' * 45) + '</span>'
      expect(helper.shortened_desc(text, 1)).to eq('a' * 255 + dots + expand + more)
    end
  end

  describe "#anchored_continuity_path" do
    it "anchors for sectioned post" do
      section = create(:board_section)
      post = create(:post, board: section.board, section: section)
      expect(helper.anchored_continuity_path(post)).to eq(continuity_path(post.board_id) + "#section-" + section.id.to_s)
    end

    it "does not anchor for unsectioned post" do
      post = create(:post)
      expect(helper.anchored_continuity_path(post)).to eq(continuity_path(post.board_id))
    end
  end

  describe "#author_links" do
    let(:post) { create(:post) }

    context "with only deleted users" do
      before(:each) { post.user.update!(deleted: true) }

      it "handles only a deleted user" do
        expect(helper.author_links(post)).to eq('(deleted user)')
      end

      it "handles only two deleted users" do
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq('(deleted users)')
      end

      it "handles >4 deleted users" do
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
        post.user.update!(deleted: true)
        reply = create(:reply, post: post)
        expect(helper.author_links(post)).to eq(helper.user_link(reply.user) + ' and 1 deleted user')
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles two users with reply user deleted" do
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq(helper.user_link(post.user) + ' and 1 deleted user')
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles three users with one deleted" do
        post.user.update!(username: 'xxx')
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post, user: create(:user, username: 'yyy'))
        links = [post.user, reply.user].map { |u| helper.user_link(u) }.join(', ')
        expect(helper.author_links(post)).to eq(links + ' and 1 deleted user')
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles three users with two deleted" do
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        reply = create(:reply, post: post)
        reply.user.update!(deleted: true)
        expect(helper.author_links(post)).to eq(helper.user_link(post.user) + ' and 2 deleted users')
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles >4 users with post user first" do
        post.user.update!(username: 'zzz')
        create(:reply, post: post, user: create(:user, username: 'yyy'))
        reply = create(:reply, post: post, user: create(:user, username: 'xxx'))
        reply.user.update!(deleted: true)
        create(:reply, post: post, user: create(:user, username: 'www'))
        create(:reply, post: post, user: create(:user, username: 'vvv'))
        stats_link = helper.link_to('4 others', stats_post_path(post))
        expect(helper.author_links(post)).to eq(helper.user_link(post.user) + ' and ' + stats_link)
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles >4 users with alphabetical user first iff post user deleted" do
        post.user.update!(username: 'zzz', deleted: true)
        create(:reply, post: post, user: create(:user, username: 'yyy'))
        create(:reply, post: post, user: create(:user, username: 'xxx'))
        reply = create(:reply, post: post, user: create(:user, username: 'aaa'))
        create(:reply, post: post, user: create(:user, username: 'vvv'))
        stats_link = helper.link_to('4 others', stats_post_path(post))
        expect(helper.author_links(post)).to eq(helper.user_link(reply.user) + ' and ' + stats_link)
        expect(helper.author_links(post)).to be_html_safe
      end
    end

    context "with only active users" do
      it "handles only one user" do
        expect(helper.author_links(post)).to eq(helper.user_link(post.user))
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles two users with commas" do
        post.user.update!(username: 'xxx')
        reply = create(:reply, post: post, user: create(:user, username: 'yyy'))
        expect(helper.author_links(post)).to eq(helper.user_link(post.user) + ', ' + helper.user_link(reply.user))
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles three users with commas and no and" do
        post.user.update!(username: 'zzz')
        users = [post.user]
        users << create(:reply, post: post, user: create(:user, username: 'yyy')).user
        users << create(:reply, post: post, user: create(:user, username: 'xxx')).user
        expect(helper.author_links(post)).to eq(users.reverse.map { |u| helper.user_link(u) }.join(', '))
        expect(helper.author_links(post)).to be_html_safe
      end

      it "handles >4 users with post user first" do
        post.user.update!(username: 'zzz')
        create(:reply, post: post, user: create(:user, username: 'yyy'))
        create(:reply, post: post, user: create(:user, username: 'xxx'))
        create(:reply, post: post, user: create(:user, username: 'www'))
        create(:reply, post: post, user: create(:user, username: 'vvv'))
        stats_link = helper.link_to('4 others', stats_post_path(post))
        expect(helper.author_links(post)).to eq(helper.user_link(post.user) + ' and ' + stats_link)
        expect(helper.author_links(post)).to be_html_safe
      end
    end
  end

  describe "#unread_warning" do
    let(:post) { create(:post) }

    before(:each) do
      assign(:post, post)
      without_partial_double_verification do
        allow(helper).to receive(:page).and_return(1)
      end
    end

    it "returns unless replies are present" do
      expect(helper.unread_warning).to eq(nil)
    end

    it "returns on the last page" do
      create(:reply, post: post)
      assign(:replies, post.replies.paginate(page: 1))
      expect(helper.unread_warning).to eq(nil)
    end

    it "returns html on earlier pages" do
      create_list(:reply, 26, post: post)
      assign(:replies, post.replies.paginate(page: 1))
      html = 'You are not on the latest page of the thread '
      html += tag.a('(View unread)', href: unread_path(post), class: 'unread-warning') + ' '
      html += tag.a('(New tab)', href: unread_path(post), class: 'unread-warning', target: '_blank')
      expect(helper.unread_warning).to eq(html)
    end
  end

  describe "#dropdown_icons" do
    let(:user) { create(:user) }
    let(:post) { build(:post, user: user) }
    let(:character) { create(:character, user: user) }

    before(:each) do
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(user)
      end
    end

    it "returns an empty string with no icons" do
      create_list(:icon, 3, user: user)
      expect(helper.dropdown_icons(post)).to eq('')
    end

    it "returns avatar with no character" do
      avatar = create(:icon)
      user.update!(avatar: avatar)
      html = select_tag :icon_dropdown, options_for_select([[avatar.keyword, avatar.id]], avatar.id), prompt: "No Icon"
      expect(helper.dropdown_icons(post)).to eq(html)
    end

    it "returns icons collection if galleries" do
      icons = create_list(:icon, 3, user: user)
      character.galleries << create(:gallery, user: user, icons: icons[0..1])
      character.galleries << create(:gallery, user: user, icons: [icons.last])
      icons = Icon.where(id: icons.map(&:id))
      post.character = character
      html = select_tag :icon_dropdown, options_for_select(icons.ordered.map{|i| [i.keyword, i.id]}, nil), prompt: "No Icon"
      expect(helper.dropdown_icons(post, character.galleries)).to eq(html)
    end

    it "returns icons if character has icons" do
      icons = create_list(:icon, 3, user: user)
      character.galleries << create(:gallery, icons: icons)
      post.character = character
      post.icon = icons[0]
      icons = Icon.where(id: icons.map(&:id)).ordered
      html = select_tag :icon_dropdown, options_for_select(icons.map{|i| [i.keyword, i.id]}, post.icon_id), prompt: "No Icon"
      expect(helper.dropdown_icons(post)).to eq(html)
    end

    it "returns default icon if character only has that" do
      icon = create(:icon, user: user)
      character.update!(default_icon: icon)
      post.character = character
      html = select_tag :icon_dropdown, options_for_select([[icon.keyword, icon.id]], nil), prompt: "No Icon"
      expect(helper.dropdown_icons(post)).to eq(html)
    end

    it "returns icon if post icon" do
      icon = create(:icon, user: user)
      post.character = character
      post.icon = icon
      html = select_tag :icon_dropdown, options_for_select([[icon.keyword, icon.id]], icon.id), prompt: "No Icon"
      expect(helper.dropdown_icons(post)).to eq(html)
    end
  end
end
