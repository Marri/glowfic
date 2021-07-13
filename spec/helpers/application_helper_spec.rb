RSpec.describe ApplicationHelper do
  describe "#sanitize_simple_link_text" do
    it "remains blank if given blank" do
      text = ''
      expect(helper.sanitize_simple_link_text(text)).to eq(text)
    end

    it "does not malform plain text" do
      text = 'sample text'
      expect(helper.sanitize_simple_link_text(text)).to eq(text)
    end

    it "permits links" do
      text = 'here is <a href="http://example.com">a link</a> '
      text += '<a href="https://example.com">another link</a> '
      text += '<a href="/characters/1">yet another link</a>'
      result = helper.sanitize_simple_link_text(text)
      expect(result).to eq(text)
      expect(result).to be_html_safe
    end

    it "removes unpermitted attributes" do
      text = '<a onclick="function(){ alert("bad!");}">test</a>'
      expect(helper.sanitize_simple_link_text(text)).to eq('<a>test</a>')
    end

    it "removes unpermitted elements" do
      text = '<b>test</b> <script type="text/javascript">alert("bad!");</script> <p>text</p>'
      expect(helper.sanitize_simple_link_text(text)).to eq('test   text ')
    end

    it "fixes unending tags" do
      text = '<a>test'
      expect(helper.sanitize_simple_link_text(text)).to eq('<a>test</a>')
    end
  end

  describe "#sanitize_written_content" do
    ['RTF', 'HTML'].each do |editor_mode|
      # applies only for single-line input
      def format_input(text, editor_mode)
        return text if editor_mode == 'HTML'
        "<p>#{text}</p>"
      end

      context "shared examples in #{editor_mode} mode" do
        it "is blank if given blank" do
          text = ''
          expect(helper.sanitize_written_content(format_input(text, editor_mode))).to eq("<p>#{text}</p>")
        end

        it "does not malform plain text" do
          text = 'sample text'
          expect(helper.sanitize_written_content(format_input(text, editor_mode))).to eq("<p>#{text}</p>")
        end

        it "permits links" do
          text = 'here is <a href="http://example.com">a link</a> '
          text += '<a href="https://example.com">another link</a> '
          text += '<a href="/characters/1">yet another link</a>'
          expect(helper.sanitize_written_content(format_input(text, editor_mode))).to eq("<p>#{text}</p>")
        end

        it "permits images" do
          text = 'images: <img src="http://example.com/image.png"> <img src="https://example.com/image.jpg"> <img src="/image.gif">'
          result = helper.sanitize_written_content(format_input(text, editor_mode))
          expect(result).to eq("<p>#{text}</p>")
          expect(result).to be_html_safe
        end

        it "removes unpermitted attributes" do
          text = '<a onclick="function(){ alert("bad!");}">test</a>'
          expect(helper.sanitize_written_content(format_input(text, editor_mode))).to eq("<p><a>test</a></p>")
        end

        it "permits valid CSS" do
          text = '<a style="color: red;">test</a>'
          expect(helper.sanitize_written_content(format_input(text, editor_mode))).to eq("<p>#{text}</p>")
        end

        it "fixes unending tags" do
          text = '<a>test'
          expect(helper.sanitize_written_content(format_input(text, editor_mode))).to eq("<p><a>test</a></p>")
        end
      end
    end

    context "with linebreak tags" do
      # RTF editor or HTML editor with manual tags
      it "removes unpermitted elements" do
        text = '<b>test</b> <script type="text/javascript">alert("bad!");</script> <p>text</p>'
        result = helper.sanitize_written_content(text)
        expect(result).to eq('<b>test</b>  <p>text</p>')
        expect(result).to be_html_safe
      end

      it "permits some attributes on only some tags" do
        text = '<p><a width="100%" href="https://example.com">test</a></p> <hr width="100%">'
        expected = '<p><a href="https://example.com">test</a></p> <hr width="100%">'
        expect(helper.sanitize_written_content(text)).to eq(expected)
      end

      it "does not convert linebreaks in text with <br> tags" do
        text = "line1<br>line2\nline3"
        display = text
        expect(helper.sanitize_written_content(text)).to eq(display)

        text = "line1<br/>line2\nline3"
        expect(helper.sanitize_written_content(text)).to eq(display)

        text = "line1<br />line2\nline3"
        expect(helper.sanitize_written_content(text)).to eq(display)
      end

      it "does not convert linebreaks in text with <p> tags" do
        text = "<p>line1</p><p>line2\nline3</p>"
        expect(helper.sanitize_written_content(text)).to eq(text)
      end

      it "does not convert linebreaks in text with complicated <p> tags" do
        text = "<p style=\"width: 100%;\">line1\nline2</p>"
        expect(helper.sanitize_written_content(text)).to eq(text)
      end

      it "does not touch blockquotes" do
        text = "<blockquote>Blah. Blah.<br />Blah.</blockquote>\n<blockquote>Blah blah.</blockquote>\n<p>Blah.</p>"
        expected = "<blockquote>Blah. Blah.<br>Blah.</blockquote>\n<blockquote>Blah blah.</blockquote>\n<p>Blah.</p>"
        expect(helper.sanitize_written_content(text)).to eq(expected)
      end
    end

    context "without linebreak tags" do
      it "automatically converts linebreaks" do
        text = "line1\nline2\n\nline3"
        result = helper.sanitize_written_content(text)
        expect(result).to eq("<p>line1\n<br>line2</p>\n\n<p>line3</p>")
        expect(result).to be_html_safe
      end

      it "defaults to old linebreak-to-br format when blockquote detected" do
        text = "<blockquote>Blah. Blah.\r\nBlah.\r\n\r\nBlah blah.</blockquote>\r\nBlah."
        expected = "<blockquote>Blah. Blah.<br>Blah.<br><br>Blah blah.</blockquote><br>Blah."
        expect(helper.sanitize_written_content(text)).to eq(expected)
      end

      it "does not mangle large breaks" do
        text = "line1\n\n\nline2"
        expected = "<p>line1</p>\n\n<p>\n<br>line2</p>"
        expect(helper.sanitize_written_content(text)).to eq(expected)

        text = "line1\n\n\n\nline2"
        expected = "<p>line1</p>\n\n<p>&nbsp;</p>\n\n<p>line2</p>" # U+00A0 is NBSP
        expect(helper.sanitize_written_content(text)).to eq(expected)
      end

      it "does not mangle tags continuing over linebreaks" do
        text = "line1<b>text\nline2</b>"
        expected = "<p>line1<b>text\n<br>line2</b></p>"
        expect(helper.sanitize_written_content(text)).to eq(expected)

        text = "line1<b>text\n\nline2</b>"
        expected = "<p>line1<b>text</b></p><b>\n\n</b><p><b>line2</b></p>"
        expect(helper.sanitize_written_content(text)).to eq(expected)
      end
    end
  end

  describe "#breakable_text" do
    it "leaves blank strings intact" do
      expect(helper.send(:breakable_text, nil)).to eq(nil)
      expect(helper.send(:breakable_text, '')).to eq('')
    end

    it "does not do anything special to linebreaks" do
      expect(helper.send(:breakable_text, "text\ntext")).to eq("text\ntext")
      expect(helper.send(:breakable_text, "text\r\ntext")).to eq("text\r\ntext")
    end

    it "escapes HTML elements" do
      text = "screenname <b>text</b> &amp; more text"
      expected = "screenname &lt;b&gt;text&lt;/b&gt; &amp;amp; more text"
      result = helper.send(:breakable_text, text)
      expect(result).to eq(expected)
      expect(result).to be_html_safe
    end

    it "leaves simple text intact" do
      text = "screenname"
      expected = text
      expect(helper.send(:breakable_text, text)).to eq(expected)
    end

    it "leaves hyphenated text intact" do
      text = "screen-name"
      expected = text
      expect(helper.send(:breakable_text, text)).to eq(expected)

      text = "-screen-name-"
      expected = text
      expect(helper.send(:breakable_text, text)).to eq(expected)
    end

    it "adds wordbreak opportunities after underscores" do
      text = "screen_name"
      expected = "screen_<wbr>name"
      expect(helper.send(:breakable_text, text)).to eq(expected)
    end
  end

  describe "#allowed_boards" do
    it "includes open-to-everyone boards" do
      board = create(:board)
      user = create(:user)
      post = build(:post)
      expect(helper.allowed_boards(post, user)).to eq([board])
    end

    it "includes locked boards with user in" do
      user = create(:user)
      board = create(:board, authors_locked: true, authors: [user])
      post = build(:post)
      expect(helper.allowed_boards(post, user)).to eq([board])
    end

    it "hides boards that user can't write in" do
      create(:board, authors_locked: true)
      user = create(:user)
      post = build(:post)
      expect(helper.allowed_boards(post, user)).to eq([])
    end

    it "shows the post's board even if the user can't write in it" do
      board = create(:board, authors_locked: true)
      user = create(:user)
      post = build(:post, board: board)
      expect(helper.allowed_boards(post, user)).to eq([board])
    end

    it "orders boards" do
      board_a = create(:board, name: "A")
      board_b_pinned = create(:board, name: "B", pinned: true)
      board_c = create(:board, name: "C")
      user = create(:user)
      post = build(:post)
      expect(helper.allowed_boards(post, user)).to eq([board_b_pinned, board_a, board_c])
    end
  end

  describe "#swap_icon_url" do
    let(:user) { create(:user) }
    let(:swap) { 'icons/swap.png' }
    let(:swap_grey) { 'icons/swapgray.png' }

    before(:each) do
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(user)
      end
    end

    it "handles no user" do
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(nil)
      end
      expect(helper.swap_icon_url).to eq(swap)
    end

    it "handles no layout" do
      expect(helper.swap_icon_url).to eq(swap)
    end

    it "handles starries" do
      user.update!(layout: 'starrydark')
      expect(helper.swap_icon_url).to eq(swap_grey)
      user.update!(layout: 'starrylight')
      expect(helper.swap_icon_url).to eq(swap_grey)
    end

    it "handles dark" do
      user.update!(layout: 'dark')
      expect(helper.swap_icon_url).to eq(swap_grey)
    end

    it "handles other themes" do
      user.update!(layout: 'monochrome')
      expect(helper.swap_icon_url).to eq(swap)
    end
  end

  describe "#fun_name" do
    let(:user) { create(:user) }

    it "returns deleted user for deleted users" do
      user.update!(deleted: true)
      expect(helper.fun_name(user)).to eq('(deleted user)')
    end

    it "returns username for users without moieties" do
      expect(helper.fun_name(user)).to eq(user.username)
    end

    it "returns colored username for users with moieties" do
      color = '111111'
      user.update!(moiety: color)
      html = tag.span user.username, style: "font-weight: bold; color: ##{color}"
      expect(helper.fun_name(user)).to eq(html)
    end
  end

  shared_examples "link_img" do
    let(:user) { create(:user) }

    before(:each) do
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(user)
      end
    end

    it "handles no user" do
      without_partial_double_verification do
        allow(helper).to receive(:current_user).and_return(nil)
      end
      expect(method).to eq(icon)
    end

    it "handles no layout" do
      expect(method).to eq(icon)
    end

    it "handles dark" do
      user.update!(layout: 'dark')
      expect(method).to eq(dark_icon)
    end

    it "handles starrydark" do
      user.update!(layout: 'starrydark')
      expect(method).to eq(dark_icon)
    end

    it "handles other themes" do
      user.update!(layout: 'monochrome')
      expect(method).to eq(icon)
    end
  end

  describe "#unread_img" do
    let(:icon) { 'icons/note_go.png' }
    let(:dark_icon) { 'icons/bullet_go.png' }
    let(:method) { helper.unread_img }

    include_examples 'link_img'
  end

  describe "#lastlink_img" do
    let(:icon) { 'icons/note_go_strong.png' }
    let(:dark_icon) { 'icons/bullet_go_strong.png' }
    let(:method) { helper.lastlink_img }

    include_examples 'link_img'
  end

  describe "#per_page_options" do
    let(:options) { {10=>10, 25=>25, 50=>50, 100=>100} }

    it "handles no default" do
      without_partial_double_verification do
        allow(helper).to receive(:per_page).and_return(25)
      end
      html = options_for_select(options, 25)
      expect(helper.per_page_options).to eq(html)
    end

    it "handles default greater than 100" do
      html = options_for_select(options, nil)
      expect(helper.per_page_options(200)).to eq(html)
    end

    it "handles zero default" do
      html = options_for_select(options, 0)
      expect(helper.per_page_options(0)).to eq(html)
    end

    it "handles normal default" do
      html = options_for_select(options, 25)
      expect(helper.per_page_options(25)).to eq(html)
    end

    it "handles custom default" do
      options = {10=>10, 25=>25, 30=>30, 50=>50, 100=>100}
      html = options_for_select(options, 30)
      expect(helper.per_page_options(30)).to eq(html)
    end
  end

  shared_examples "unread_or_opened" do
    let(:post) { create(:post) }

    it "requires a post" do
      expect(method(nil, [1, 2])).to eq(false)
    end

    it "requires an id list" do
      expect(method(post, nil)).to eq(false)
    end

    it "returns true if id in list" do
      expect(method(post, [1, 2, post.id])).to eq(true)
    end

    it "returns false if id not in list" do
      expect(method(post, [1, 2])).to eq(false)
    end
  end

  describe "#unread_post?" do
    def method(post, ids)
      helper.unread_post?(post, ids)
    end

    include_examples 'unread_or_opened'
  end

  describe "#opened_post?" do
    def method(post, ids)
      helper.opened_post?(post, ids)
    end

    include_examples 'unread_or_opened'
  end
end
