RSpec.describe WritableController do
  describe "#setup_layout_gon" do
    it "does not error when logged out" do
      controller.send(:setup_layout_gon)
    end

    it "works when logged in with default theme" do
      login
      controller.send(:setup_layout_gon)
      expect(controller.gon.editor_class).to be_nil
      expect(controller.gon.base_url).not_to be_nil
    end

    context "with dark theme" do
      ['dark', 'starrydark'].each do |theme|
        it "works with theme '#{theme}'" do
          user = create(:user, layout: theme)
          login_as(user)
          controller.send(:setup_layout_gon)
          expect(controller.gon.editor_class).to eq('layout_' + theme)
          expect(controller.gon.base_url).not_to be_nil
          expect(controller.gon.tinymce_css_path).not_to be_nil
        end
      end
    end
  end

  describe "#og_data_for_post" do
    let(:board) { create(:board, name: 'Test') }
    let(:user) { create(:user, username: 'Tester') }
    let(:post) { create(:post, subject: 'Temp', board: board, user: user) }

    it "succeeds" do
      data = controller.send(:og_data_for_post, post, total_pages: 5)
      expect(data).to eq({
        title: 'Temp · Test',
        description: '(Tester – page 1 of 5)'
      })
    end

    it "works with description" do
      post = create(:post, subject: 'Temp', description: 'More.', board: board, user: user)

      data = controller.send(:og_data_for_post, post, total_pages: 5)
      expect(data).to eq({
        title: 'Temp · Test',
        description: 'More. (Tester – page 1 of 5)'
      })
    end

    it "strips tags from description" do
      post = create(:post, subject: 'Temp', description: 'With an <a href="/characters/1">Alli</a>.', board: board, user: user)

      data = controller.send(:og_data_for_post, post, total_pages: 5)
      expect(data).to eq({
        title: 'Temp · Test',
        description: 'With an Alli. (Tester – page 1 of 5)'
      })
    end

    it "works with section" do
      section = create(:board_section, board: board, name: 'Further')
      post = create(:post, subject: 'Temp', description: 'More.', board: board, section: section, user: user)

      data = controller.send(:og_data_for_post, post, total_pages: 5)
      expect(data).to eq({
        title: 'Temp · Test » Further',
        description: 'More. (Tester – page 1 of 5)'
      })
    end

    it "works with two authors" do
      user2 = create(:user, username: 'Friend')
      post = create(:post, subject: 'Temp', description: 'More.', board: board, user: user)
      create(:reply, post: post, user: user2)

      data = controller.send(:og_data_for_post, post, total_pages: 5)
      expect(data).to eq({
        title: 'Temp · Test',
        description: 'More. (Friend, Tester – page 1 of 5)'
      })
    end

    it "works with pages that are not the first" do
      data = controller.send(:og_data_for_post, post, page: 2, total_pages: 2)
      expect(data).to eq({
        title: 'Temp · Test',
        description: '(Tester – page 2 of 2)'
      })
    end

    it "works with many authors" do
      5.times do |i|
        user2 = create(:user, username: "Friend #{i}")
        create(:reply, post: post, user: user2)
      end

      data = controller.send(:og_data_for_post, Post.find_by(id: post.id), total_pages: 5)
      expect(data).to eq({
        title: 'Temp · Test',
        description: '(Tester and 5 others – page 1 of 5)'
      })
    end

    it "works with non-standard per_page" do
      data = controller.send(:og_data_for_post, post, total_pages: 5, per_page: 5)
      expect(data).to eq({
        title: 'Temp · Test',
        description: '(Tester – page 1 of 5, 5/page)'
      })
    end
  end

  describe "#build_template_groups" do
    let(:user) { create(:user) }

    before(:each) { login_as(user) }

    it "orders templates correctly" do
      template2 = create(:template, user: user, name: "b")
      template3 = create(:template, user: user, name: "c")
      template1 = create(:template, user: user, name: "a")
      create(:character, user: user, template: template1)
      create(:character, user: user, template: template2)
      create(:character, user: user, template: template3)
      controller.send(:build_template_groups)
      expect(assigns(:templates)).not_to be_empty
      expect(assigns(:templates)).to eq([template1, template2, template3])
    end

    it "orders templateless characters correctly" do
      char2 = create(:character, user: user, name: "b")
      char3 = create(:character, user: user, name: "c")
      char1 = create(:character, user: user, name: "a")
      controller.send(:build_template_groups)
      templates = assigns(:templates)
      expect(templates.count).to eq(1)
      expect(templates.first.plucked_characters.map(&:first)).to eq([char1, char2, char3].map(&:id))
    end

    describe "with post" do
      it "orders thread characters correctly" do
        char3 = create(:character, user: user, name: 'c')
        char1 = create(:character, user: user, name: 'a')
        char2 = create(:character, user: user, name: 'b')
        create(:character, user: user)
        post = create(:post, user: user, character: char2)
        create(:reply, post: post, user: user, character: char3)
        create(:reply, post: post, user: user, character: char1)
        controller.instance_variable_set(:@post, post)
        controller.send(:build_template_groups)
        templates = assigns(:templates)
        expect(templates.count).to eq(2)
        expect(templates.first.plucked_characters.map(&:first)).to eq([char1, char2, char3].map(&:id))
      end
    end

    it "loads correct information for template characters" do
      template = create(:template, user: user)
      char1 = create(:character, template: template, user: user, name: 'AAAA')
      char2 = create(:character, template: template, user: user, nickname: "nickname", name: 'BBBB')
      char3 = create(:character, template: template, user: user, screenname: "screen_name", name: 'CCCC')
      char4 = create(:character, template: template, user: user, name: 'DDDD', screenname: "other_sceen", nickname: "Nickname")
      controller.send(:build_template_groups)
      templates = assigns(:templates)
      expect(templates.count).to eq(1)
      info = [
        [char1.id, char1.name],
        [char2.id, "#{char2.name} | #{char2.nickname}"],
        [char3.id, "#{char3.name} | #{char3.screenname}"],
        [char4.id, "#{char4.name} | #{char4.nickname} | #{char4.screenname}"]
      ]
      expect(templates.first.plucked_characters).to eq(info)
    end

    it "loads correct information for templateless characters" do
      char1 = create(:character, user: user, name: 'AAAA')
      char2 = create(:character, user: user, nickname: "nickname", name: 'BBBB')
      char3 = create(:character, user: user, screenname: "screen_name", name: 'CCCC')
      char4 = create(:character, user: user, name: 'DDDD', screenname: "other_sceen", nickname: "Nickname")
      login_as(user)
      controller.send(:build_template_groups)
      templates = assigns(:templates)
      expect(templates.count).to eq(1)
      info = [
        [char1.id, char1.name],
        [char2.id, "#{char2.name} | #{char2.nickname}"],
        [char3.id, "#{char3.name} | #{char3.screenname}"],
        [char4.id, "#{char4.name} | #{char4.nickname} | #{char4.screenname}"]
      ]
      expect(templates.first.plucked_characters).to eq(info)
    end

    it "excludes retired templateless characters" do
      template = create(:template, user: user)
      char1 = create(:character, template: template, user: user, name: 'AAAA')
      create_list(:character, 2, template: template, user: user, retired: true)
      char2 = create(:character, template: template, user: user, name: 'DDDD', screenname: "screen_name", nickname: "Nickname")
      controller.send(:build_template_groups)
      templates = assigns(:templates)
      expect(templates.count).to eq(1)
      info = [
        [char1.id, char1.name],
        [char2.id, "#{char2.name} | #{char2.nickname} | #{char2.screenname}"]
      ]
      expect(templates.first.plucked_characters).to eq(info)
    end

    it "has more tests" do
      skip
    end
  end
end
