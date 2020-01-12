require "spec_helper"

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
end
