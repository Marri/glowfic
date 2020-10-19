RSpec.describe CharactersController do
  include ActiveJob::TestHelper

  describe "GET index" do
    it "requires login without an id" do
      get :index
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid id" do
      get :index, params: { user_id: -1 }
      expect(response).to redirect_to(users_url)
      expect(flash[:error]).to eq("User could not be found.")
    end

    it "succeeds with an id" do
      user = create(:user)
      get :index, params: { user_id: user.id }
      expect(response.status).to eq(200)
    end

    it "succeeds when logged in" do
      login
      get :index
      expect(response.status).to eq(200)
    end

    it "succeeds with an id when logged in" do
      user = create(:user)
      login
      get :index, params: { user_id: user.id }
      expect(response.status).to eq(200)
    end

    it "does something with character groups" do
      skip "Character groups need to be refactored"
    end

    context "with render_views" do
      render_views

      it "successfully renders the page in template group" do
        character = create(:character)
        create(:template_character, user: character.user) # character2
        get :index, params: { user_id: character.user_id, character_split: 'template' }
        expect(response.status).to eq(200)
      end

      it "successfully renders the page with no group" do
        character = create(:character)
        create(:template_character, user: character.user) # character2
        get :index, params: { user_id: character.user_id, character_split: 'none' }
        expect(response.status).to eq(200)
      end

      it "skips retired characters when specified" do
        character = create(:character, name: 'ExistingCharacter')
        create(:character, user: character.user, retired: true, name: 'RetiredCharacter')
        get :index, params: { user_id: character.user_id, retired: 'false' }
        expect(response.body).to include('ExistingCharacter')
        expect(response.body).not_to include('RetiredCharacter')
      end
    end
  end

  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "succeeds when logged in" do
      login
      get :new
      expect(response.status).to eq(200)
    end

    it "sets correct variables with template_id" do
      template = create(:template)
      login_as(template.user)
      get :new, params: { template_id: template.id }
      expect(response.status).to eq(200)
      expect(assigns(:character).template).to eq(template)
    end

    context "with views" do
      render_views
      it "sets correct variables" do
        user = create(:user)
        templates = Array.new(2) { create(:template, user: user) }
        create(:template)

        login_as(user)
        get :new

        expect(assigns(:page_title)).to eq("New Character")
        expect(assigns(:templates).map(&:name)).to match_array(templates.map(&:name))
        expect(controller.gon.character_id).to eq('')
        expect(controller.gon.user_id).to eq(user.id)
        expect(controller.gon.gallery_groups).to eq([])
        expect(assigns(:aliases)).to be_blank
      end
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "fails with missing params" do
      login
      post :create
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Character could not be created because of the following problems:")
    end

    it "fails with invalid params" do
      login
      post :create, params: { character: {} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Character could not be created because of the following problems:")
    end

    it "succeeds when valid" do
      expect(Character.count).to eq(0)
      test_name = 'Test character'
      user = create(:user)
      template = create(:template, user: user)
      gallery = create(:gallery, user: user)
      setting = create(:setting, user: user, name: 'A World')

      login_as(user)
      post :create, params: {
        character: {
          name: test_name,
          nickname: 'TempName',
          screenname: 'just-a-test',
          setting_ids: [setting.id],
          template_id: template.id,
          pb: 'Facecast',
          description: 'Desc',
          ungrouped_gallery_ids: [gallery.id]
        }
      }

      expect(response).to redirect_to(assigns(:character))
      expect(flash[:success]).to eq("Character created.")
      expect(Character.count).to eq(1)
      character = assigns(:character).reload
      expect(character.name).to eq(test_name)
      expect(character.user_id).to eq(user.id)
      expect(character.nickname).to eq('TempName')
      expect(character.screenname).to eq('just-a-test')
      expect(character.settings.pluck(:name)).to eq(['A World'])
      expect(character.template).to eq(template)
      expect(character.pb).to eq('Facecast')
      expect(character.description).to eq('Desc')
      expect(character.galleries).to match_array([gallery])
    end

    it "creates new templates when specified" do
      expect(Template.count).to eq(0)
      login
      post :create, params: {
        new_template: '1',
        character: {
          template_attributes: {
            name: 'TemplateTest'
          }, name: 'Test'
        }
      }
      expect(Template.count).to eq(1)
      expect(Template.first.name).to eq('TemplateTest')
      expect(assigns(:character).template_id).to eq(Template.first.id)
    end

    context "with views" do
      render_views
      it "sets correct variables when invalid" do
        user = create(:user)
        gallery = create(:gallery, user: user)
        group = create(:gallery_group)
        group_gallery = create(:gallery, user: user, gallery_groups: [group])
        templates = Array.new(2) { create(:template, user: user) }
        create(:template)

        login_as(user)
        post :create, params: {
          character: {
            ungrouped_gallery_ids: [gallery.id, group_gallery.id],
            gallery_group_ids: [group.id]
          }
        }

        expect(response).to render_template(:new)
        expect(controller.gon.character_id).to eq('')
        expect(assigns(:templates).map(&:name)).to match_array(templates.map(&:name))
        expect(assigns(:character).ungrouped_gallery_ids).to match_array([gallery.id, group_gallery.id])
        expect(assigns(:character).gallery_group_ids).to eq([group.id])
      end
    end
  end

  describe "GET show" do
    it "requires valid character logged out" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires valid character logged in" do
      user_id = login
      get :show, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "should succeed when logged out" do
      character = create(:character)
      get :show, params: { id: character.id }
      expect(response.status).to eq(200)
    end

    it "should succeed when logged in" do
      character = create(:character)
      login
      get :show, params: { id: character.id }
      expect(response.status).to eq(200)
    end

    it "should set correct variables" do
      character = create(:character)
      Array.new(26) { create(:post, character: character, user: character.user) }
      get :show, params: { id: character.id }
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq(character.name)
      expect(assigns(:posts).size).to eq(25)
      expect(assigns(:posts)).to match_array(Post.where(character_id: character.id).ordered.limit(25))
    end

    it "should only show visible posts" do
      character = create(:character)
      create(:post, character: character, user: character.user, privacy: :private)
      get :show, params: { id: character.id }
      expect(assigns(:posts)).to be_blank
    end

    it "orders recent posts" do
      character = create(:character)
      post3 = create(:post)
      post1 = create(:post, user: character.user, character: character)
      post4 = create(:post, user: character.user, character: character)
      post2 = create(:post)
      create(:reply, post: post4)
      create(:reply, post: post3, user: character.user, character: character)
      create(:reply, post: post2, user: character.user, character: character)
      create(:reply, post: post1)
      get :show, params: { id: character.id }
      expect(assigns(:posts)).to eq([post1, post2, post3, post4])
    end

    it "calculates OpenGraph meta for basic character" do
      user = create(:user, username: 'John Doe')
      character = create(:character,
        user: user,
        name: "Alice",
        screenname: "player_one",
        description: "Alice is a character",
      )

      get :show, params: { id: character.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(character_url(character))
      expect(meta_og[:title]).to eq('John Doe » Alice | player_one')
      expect(meta_og[:description]).to eq("Alice is a character")
    end

    it "calculates OpenGraph meta for expanded character" do
      user = create(:user, username: 'John Doe')
      character = create(:character,
        user: user,
        template: create(:template, name: "A"),
        name: "Alice",
        nickname: "Lis",
        screenname: "player_one",
        settings: [
          create(:setting, name: 'Infosec'),
          create(:setting, name: 'Wander'),
        ],
        description: "Alice is a character",
        with_default_icon: true,
      )
      create(:alias, character: character, name: "Alicia")
      create(:post, character: character, user: user)
      create(:reply, character: character, user: user)

      get :show, params: { id: character.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description, :image])
      expect(meta_og[:url]).to eq(character_url(character))
      expect(meta_og[:title]).to eq('John Doe » A » Alice | player_one')
      expect(meta_og[:description]).to eq("Nicknames: Lis, Alicia. Settings: Infosec, Wander\nAlice is a character\n2 posts")
      expect(meta_og[:image].keys).to match_array([:src, :width, :height])
      expect(meta_og[:image][:src]).to eq(character.default_icon.url)
      expect(meta_og[:image][:height]).to eq('75')
      expect(meta_og[:image][:width]).to eq('75')
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character id" do
      user_id = login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires character with permissions" do
      user_id = login
      get :edit, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("You do not have permission to modify this character.")
    end

    it "succeeds when logged in" do
      character = create(:character)
      login_as(character.user)
      get :edit, params: { id: character.id }
      expect(response.status).to eq(200)
    end

    context "with views" do
      render_views
      it "sets correct variables" do
        user = create(:user)
        group = create(:gallery_group)
        gallery = create(:gallery, user: user, gallery_groups: [group])
        character = create(:character, user: user, gallery_groups: [group])
        calias = create(:alias, character: character)
        templates = Array.new(2) { create(:template, user: user) }
        create(:template)

        login_as(user)
        get :edit, params: { id: character.id }

        expect(assigns(:page_title)).to eq("Edit Character: #{character.name}")
        expect(controller.gon.character_id).to eq(character.id)
        expect(controller.gon.user_id).to eq(user.id)
        expect(controller.gon.gallery_groups.map{|g| g[:id]}).to eq([group.id])
        expect(controller.gon.gallery_groups.map{|g| g[:gallery_ids]}).to eq([[gallery.id]])
        expect(assigns(:character).gallery_groups).to match_array([group])
        expect(assigns(:templates).map(&:name)).to match_array(templates.map(&:name))
        expect(assigns(:aliases)).to match_array([calias])
      end

      it "works for moderator with untemplated character" do
        user = create(:mod_user)
        login_as(user)
        character = create(:character)
        template = create(:template, user: character.user)

        get :edit, params: { id: character.id }

        expect(assigns(:page_title)).to eq("Edit Character: #{character.name}")
        expect(controller.gon.character_id).to eq(character.id)
        expect(controller.gon.user_id).to eq(character.user.id)
        expect(assigns(:templates)).to match_array([template])
      end

      it "works for moderator with templated character" do
        user = create(:mod_user)
        login_as(user)
        character = create(:template_character)
        template = create(:template, user: character.user)

        get :edit, params: { id: character.id }

        expect(assigns(:page_title)).to eq("Edit Character: #{character.name}")
        expect(controller.gon.character_id).to eq(character.id)
        expect(controller.gon.user_id).to eq(character.user.id)
        expect(assigns(:templates)).to match_array([character.template, template])
      end
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character id" do
      user_id = login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires character with permissions" do
      user_id = login
      put :update, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("You do not have permission to modify this character.")
    end

    it "fails with invalid params" do
      character = create(:character)
      login_as(character.user)
      put :update, params: { id: character.id, character: {name: ''} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Character could not be updated because of the following problems:")
    end

    it "fails with invalid template params" do
      character = create(:character)
      login_as(character.user)
      new_name = character.name + 'aaa'
      put :update, params: {
        id: character.id,
        new_template: '1',
        character: {
          template_attributes: {name: ''},
          name: new_name
        }
      }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Character could not be updated because of the following problems:")
      expect(character.reload.name).not_to eq(new_name)
    end

    it "requires notes from moderators" do
      character = create(:character, name: 'a')
      login_as(create(:mod_user))
      put :update, params: { id: character.id, character: { name: 'b' } }
      expect(response).to render_template(:edit)
      expect(flash[:error]).to eq('You must provide a reason for your moderator edit.')
    end

    it "stores note from moderators" do
      Character.auditing_enabled = true
      character = create(:character, name: 'a')
      admin = create(:admin_user)
      login_as(admin)
      put :update, params: { id: character.id, character: { name: 'b', audit_comment: 'note' } }
      expect(flash[:success]).to eq("Character updated.")
      expect(character.reload.name).to eq('b')
      expect(character.audits.last.comment).to eq('note')
      Character.auditing_enabled = false
    end

    it "succeeds when valid" do
      character = create(:character)
      user = character.user
      login_as(user)
      new_name = character.name + 'aaa'
      template = create(:template, user: user)
      gallery = create(:gallery, user: user)
      setting = create(:setting, name: 'Another World')
      put :update, params: {
        id: character.id,
        character: {
          name: new_name,
          nickname: 'TemplateName',
          screenname: 'a-new-test',
          setting_ids: [setting.id],
          template_id: template.id,
          pb: 'Actor',
          description: 'Description',
          ungrouped_gallery_ids: [gallery.id]
        }
      }

      expect(response).to redirect_to(assigns(:character))
      expect(flash[:success]).to eq("Character updated.")
      character.reload
      expect(character.name).to eq(new_name)
      expect(character.nickname).to eq('TemplateName')
      expect(character.screenname).to eq('a-new-test')
      expect(character.settings.pluck(:name)).to eq(['Another World'])
      expect(character.template).to eq(template)
      expect(character.pb).to eq('Actor')
      expect(character.description).to eq('Description')
      expect(character.galleries).to match_array([gallery])
    end

    it "does not persist values when invalid" do
      character = create(:character)
      user = character.user
      login_as(user)
      old_name = character.name
      template = create(:template, user: user)
      gallery = create(:gallery, user: user)
      setting = create(:setting, name: 'Another World')

      put :update, params: {
        id: character.id,
        character: {
          name: '',
          nickname: 'TemplateName',
          screenname: 'a-new-test',
          setting_ids: [setting.id],
          template_id: template.id,
          pb: 'Actor',
          description: 'Description',
          ungrouped_gallery_ids: [gallery.id]
        }
      }

      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Character could not be updated because of the following problems:")
      character.reload
      expect(character.name).to eq(old_name)
      expect(character.nickname).to be_nil
      expect(character.screenname).to be_nil
      expect(character.settings).to be_blank
      expect(character.template).to be_blank
      expect(character.pb).to be_nil
      expect(character.description).to be_nil
      expect(character.galleries).to be_blank
    end

    it "adds galleries by groups" do
      user = create(:user)
      group = create(:gallery_group)
      gallery = create(:gallery, gallery_groups: [group], user: user)
      character = create(:character, user: user)
      login_as(user)
      put :update, params: { id: character.id, character: {gallery_group_ids: [group.id]} }

      expect(flash[:success]).to eq('Character updated.')
      character.reload
      expect(character.gallery_groups).to match_array([group])
      expect(character.galleries).to match_array([gallery])
      expect(character.ungrouped_gallery_ids).to be_blank
      expect(character.characters_galleries.first).to be_added_by_group
    end

    it "creates new templates when specified" do
      expect(Template.count).to eq(0)
      character = create(:character)
      login_as(character.user)
      put :update, params: { id: character.id, new_template: '1', character: {template_attributes: {name: 'Test'}} }
      expect(Template.count).to eq(1)
      expect(Template.first.name).to eq('Test')
      expect(character.reload.template_id).to eq(Template.first.id)
    end

    it "removes gallery only if not shared between groups" do
      user = create(:user)
      group1 = create(:gallery_group) # gallery1
      group2 = create(:gallery_group) # -> gallery1
      group3 = create(:gallery_group) # gallery2 ->
      group4 = create(:gallery_group) # gallery2
      gallery1 = create(:gallery, gallery_groups: [group1, group2], user: user)
      gallery2 = create(:gallery, gallery_groups: [group3, group4], user: user)
      character = create(:character, gallery_groups: [group1, group3, group4], user: user)
      login_as(user)
      put :update, params: { id: character.id, character: {gallery_group_ids: [group2.id, group4.id]} }

      expect(flash[:success]).to eq('Character updated.')
      character.reload
      expect(character.gallery_groups).to match_array([group2, group4])
      expect(character.galleries).to match_array([gallery1, gallery2])
      expect(character.ungrouped_gallery_ids).to be_blank
      expect(character.characters_galleries.map(&:added_by_group)).to eq([true, true])
    end

    it "does not remove gallery if tethered by group" do
      user = create(:user)
      group = create(:gallery_group)
      gallery = create(:gallery, gallery_groups: [group], user: user)
      character = create(:character, gallery_groups: [group], user: user)
      character.ungrouped_gallery_ids = [gallery.id]
      character.save!
      expect(character.characters_galleries.first).not_to be_added_by_group

      login_as(user)
      put :update, params: {
        id: character.id,
        character: {
          ungrouped_gallery_ids: [''],
          gallery_group_ids: [group.id]
        }
      }
      expect(flash[:success]).to eq('Character updated.')
      character.reload
      expect(character.gallery_groups).to match_array([group])
      expect(character.galleries).to match_array([gallery])
      expect(character.ungrouped_gallery_ids).to be_blank
      expect(character.characters_galleries.first).to be_added_by_group
    end

    it "works when adding both group and gallery" do
      user = create(:user)
      group = create(:gallery_group)
      gallery = create(:gallery, gallery_groups: [group], user: user)
      character = create(:character, user: user)

      login_as(user)
      put :update, params: {
        id: character.id,
        character: {
          gallery_group_ids: [group.id],
          ungrouped_gallery_ids: [gallery.id]
        }
      }
      expect(flash[:success]).to eq('Character updated.')
      character.reload
      expect(character.gallery_groups).to match_array([group])
      expect(character.galleries).to match_array([gallery])
      expect(character.ungrouped_gallery_ids).to eq([gallery.id])
      expect(character.characters_galleries.first).not_to be_added_by_group
    end

    it "does not add another user's galleries" do
      group = create(:gallery_group)
      create(:gallery, gallery_groups: [group]) # gallery
      character = create(:character)

      login_as(character.user)
      put :update, params: { id: character.id, character: {gallery_group_ids: [group.id]} }
      expect(flash[:success]).to eq('Character updated.')
      character.reload
      expect(character.gallery_groups).to match_array([group])
      expect(character.galleries).to be_blank
    end

    it "removes untethered galleries when group goes" do
      user = create(:user)
      group = create(:gallery_group)
      create(:gallery, gallery_groups: [group], user: user) # gallery
      character = create(:character, gallery_groups: [group], user: user)

      login_as(user)
      put :update, params: { id: character.id, character: {gallery_group_ids: ['']} }
      expect(flash[:success]).to eq('Character updated.')
      character.reload
      expect(character.gallery_groups).to eq([])
      expect(character.galleries).to eq([])
    end

    context "with views" do
      render_views
      it "sets correct variables when invalid" do
        user = create(:user)
        group = create(:gallery_group)
        gallery = create(:gallery, user: user, gallery_groups: [group])
        character = create(:character, user: user, gallery_groups: [group])
        templates = Array.new(2) { create(:template, user: user) }
        create(:template)

        login_as(user)
        put :update, params: { id: character.id, character: {name: '', gallery_group_ids: [group.id]} }

        expect(response).to render_template(:edit)
        expect(controller.gon.character_id).to eq(character.id)
        expect(controller.gon.user_id).to eq(user.id)
        expect(controller.gon.gallery_groups.map{|g| g[:id]}).to eq([group.id])
        expect(controller.gon.gallery_groups.map{|g| g[:gallery_ids]}).to eq([[gallery.id]])
        expect(assigns(:character).gallery_groups).to match_array([group])
        expect(assigns(:templates).map(&:name)).to match_array(templates.map(&:name))
      end
    end

    it "reorders galleries as necessary" do
      character = create(:character)
      g1 = create(:gallery, user: character.user)
      g2 = create(:gallery, user: character.user)
      character.galleries << g1
      character.galleries << g2
      g1_cg = CharactersGallery.where(gallery_id: g1.id).first
      g2_cg = CharactersGallery.where(gallery_id: g2.id).first
      expect(g1_cg.section_order).to eq(0)
      expect(g2_cg.section_order).to eq(1)

      login_as(character.user)
      put :update, params: { id: character.id, character: {ungrouped_gallery_ids: [g2.id.to_s]} }

      expect(character.reload.galleries.pluck(:id)).to eq([g2.id])
      expect(g2_cg.reload.section_order).to eq(0)
    end

    it "orders settings by default" do
      char = create(:character)
      login_as(char.user)
      setting1 = create(:setting)
      setting3 = create(:setting)
      setting2 = create(:setting)
      put :update, params: {
        id: char.id,
        character: {setting_ids: [setting1, setting2, setting3].map(&:id)}
      }
      expect(flash[:success]).to eq('Character updated.')
      expect(char.settings).to eq([setting1, setting2, setting3])
    end

    it "orders gallery groups by default" do
      user = create(:user)
      login_as(user)
      char = create(:character, user: user)
      group4 = create(:gallery_group, user: user)
      group1 = create(:gallery_group, user: user)
      group3 = create(:gallery_group, user: user)
      group2 = create(:gallery_group, user: user)
      put :update, params: {
        id: char.id,
        character: {gallery_group_ids: [group1, group2, group3, group4].map(&:id)}
      }
      expect(flash[:success]).to eq('Character updated.')
      expect(char.gallery_groups).to eq([group1, group2, group3, group4])
    end
  end

  describe "GET facecasts" do
    it "does not require login" do
      get :facecasts
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("Facecasts")
    end

    it "sets correct variables for facecast name sort" do
      chars = Array.new(3) { create(:character, pb: SecureRandom.urlsafe_base64) }
      get :facecasts
      pbs = assigns(:pbs).map(&:pb)
      expect(pbs).to match_array(chars.map(&:pb))
    end

    it "sets correct variables for character name sort: character only" do
      chars = Array.new(3) { create(:character, pb: SecureRandom.urlsafe_base64) }
      get :facecasts, params: { sort: 'name' }
      names = assigns(:pbs).map(&:item_name)
      expect(names).to match_array(chars.map(&:name))
    end

    it "sets correct variables for character name sort: template only" do
      chars = Array.new(3) { create(:template_character, pb: SecureRandom.urlsafe_base64) }
      get :facecasts, params: { sort: 'name' }
      names = assigns(:pbs).map(&:item_name)
      expect(names).to match_array(chars.map(&:template).map(&:name))
    end

    it "sets correct variables for character name sort: character and template mixed" do
      chars = Array.new(3) { create(:template_character, pb: SecureRandom.urlsafe_base64) }
      chars += Array.new(3) { create(:character, pb: SecureRandom.urlsafe_base64) }
      get :facecasts, params: { sort: 'name' }
      names = assigns(:pbs).map(&:item_name)
      expect(names).to match_array(chars.map { |c| (c.template || c).name })
    end

    it "sets correct variables for writer sort" do
      chars = Array.new(3) { create(:template_character, pb: SecureRandom.urlsafe_base64) }
      chars += Array.new(3) { create(:character, pb: SecureRandom.urlsafe_base64) }
      get :facecasts, params: { sort: 'writer' }
      user_ids = assigns(:pbs).map(&:user_id)
      expect(user_ids).to match_array(chars.map(&:user).map(&:id))
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      user_id = login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires permission" do
      user = create(:user)
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      delete :destroy, params: { id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("You do not have permission to modify this character.")
    end

    it "succeeds" do
      character = create(:character)
      login_as(character.user)
      delete :destroy, params: { id: character.id }
      expect(response).to redirect_to(user_characters_url(character.user_id))
      expect(flash[:success]).to eq("Character deleted.")
      expect(Character.find_by_id(character.id)).to be_nil
    end

    it "handles destroy failure" do
      character = create(:character)
      post = create(:post, user: character.user, character: character)
      login_as(character.user)
      expect_any_instance_of(Character).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: character.id }
      expect(response).to redirect_to(character_url(character))
      expect(flash[:error]).to eq("Character could not be deleted.")
      expect(post.reload.character).to eq(character)
    end
  end

  describe "GET replace" do
    it "requires login" do
      character = create(:character)
      get :replace, params: { id: character.id }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq('You must be logged in to view that page.')
    end

    it "requires valid character" do
      user_id = login
      get :replace, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires own character" do
      character = create(:character)
      user_id = login
      get :replace, params: { id: character.id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq('You do not have permission to modify this character.')
    end

    it "sets correct variables" do
      user = create(:user)
      character = create(:character, user: user)
      other_char = create(:character, user: user)
      other_char.default_icon = create(:icon, user: user)
      other_char.save!
      calias = create(:alias, character: other_char)
      char_post = create(:post, user: user, character: character)
      create(:reply, user: user, post: char_post, character: character) # reply
      create(:post) # other post
      char_reply2 = create(:reply, user: user, character: character) # other reply

      login_as(user)
      get :replace, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq('Replace Character: ' + character.name)

      expect(controller.gon.gallery[other_char.id][:url]).to eq(other_char.default_icon.url)
      expect(controller.gon.gallery[other_char.id][:aliases]).to eq([calias.as_json])
      expect(assigns(:posts)).to match_array([char_post, char_reply2.post])
    end

    context "with template" do
      it "sets alts correctly" do
        user = create(:user)
        template = create(:template, user: user)
        character = create(:character, user: user, template: template)
        alts = Array.new(5) { create(:character, user: user, template: template) }
        create(:character, user: user) # other character

        login_as(user)
        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Replace Character: ' + character.name)
        expect(assigns(:alts)).to match_array(alts)
        expect(assigns(:alt_dropdown).length).to eq(alts.length)
      end

      it "includes character if no others in template" do
        user = create(:user)
        template = create(:template, user: user)
        character = create(:character, user: user, template: template)
        create(:character, user: user) # other character

        login_as(user)
        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:alts)).to match_array([character])
      end
    end

    context "without template" do
      it "sets alts correctly" do
        user = create(:user)
        character = create(:character, user: user)
        alts = Array.new(5) { create(:character, user: user) }
        template = create(:template, user: user)
        create(:character, user: user, template: template) # other character

        login_as(user)
        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Replace Character: ' + character.name)
        expect(assigns(:alts)).to match_array(alts)
        expect(assigns(:alt_dropdown).length).to eq(alts.length)
      end

      it "includes character if no others in template" do
        user = create(:user)
        template = create(:template, user: user)
        character = create(:character, user: user)
        create(:character, user: user, template: template) # other character

        login_as(user)
        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:alts)).to match_array([character])
      end
    end
  end

  describe "POST do_replace" do
    it "requires login" do
      character = create(:character)
      post :do_replace, params: { id: character.id }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq('You must be logged in to view that page.')
    end

    it "requires valid character" do
      user_id = login
      post :do_replace, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires own character" do
      character = create(:character)
      user_id = login
      post :do_replace, params: { id: character.id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq('You do not have permission to modify this character.')
    end

    it "requires valid other character" do
      character = create(:character)
      login_as(character.user)
      post :do_replace, params: { id: character.id, icon_dropdown: -1 }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires other character to be yours if present" do
      character = create(:character)
      other_char = create(:character)
      login_as(character.user)
      post :do_replace, params: { id: character.id, icon_dropdown: other_char.id }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('You do not have permission to modify this character.')
    end

    it "requires valid new alias if parameter provided" do
      character = create(:character)
      login_as(character.user)
      post :do_replace, params: { id: character.id, alias_dropdown: -1 }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid new alias.')
    end

    it "requires matching new alias if parameter provided" do
      character = create(:character)
      other_char = create(:character, user: character.user)
      calias = create(:alias)
      login_as(character.user)
      post :do_replace, params: { id: character.id, alias_dropdown: calias.id, icon_dropdown: other_char.id }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid new alias.')
    end

    it "requires valid old alias if parameter provided" do
      character = create(:character)
      login_as(character.user)
      post :do_replace, params: { id: character.id, orig_alias: -1 }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid old alias.')
    end

    it "requires matching old alias if parameter provided" do
      character = create(:character)
      calias = create(:alias)
      login_as(character.user)
      post :do_replace, params: { id: character.id, orig_alias: calias.id }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid old alias.')
    end

    context "with audits enabled" do
      before(:each) { Reply.auditing_enabled = true }
      after(:each) { Reply.auditing_enabled = false }

      it "succeeds with valid other character" do
        user = create(:user)
        character = create(:character, user: user)
        other_char = create(:character, user: user)
        char_post = create(:post, user: user, character: character)
        reply = create(:reply, user: user, character: character)
        reply_post_char = reply.post.character_id

        login_as(user)
        perform_enqueued_jobs(only: UpdateModelJob) do
          post :do_replace, params: { id: character.id, icon_dropdown: other_char.id }
        end
        expect(response).to redirect_to(character_path(character))
        expect(flash[:success]).to eq('All uses of this character will be replaced.')

        expect(char_post.reload.character_id).to eq(other_char.id)
        expect(reply.reload.character_id).to eq(other_char.id)
        expect(reply.post.reload.character_id).to eq(reply_post_char) # check it doesn't replace all replies in a post

        audit = reply.audits.where(action: 'update').first
        expect(audit).not_to be(nil)
        expect(audit.user).to eq(user)
      end
    end

    it "succeeds with no other character" do
      user = create(:user)
      character = create(:character, user: user)
      char_post = create(:post, user: user, character: character)
      reply = create(:reply, user: user, character: character)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: character.id }
      end
      expect(response).to redirect_to(character_path(character))
      expect(flash[:success]).to eq('All uses of this character will be replaced.')

      expect(char_post.reload.character_id).to be_nil
      expect(reply.reload.character_id).to be_nil
    end

    it "succeeds with alias" do
      user = create(:user)
      character = create(:character, user: user)
      other_char = create(:character, user: user)
      calias = create(:alias, character: other_char)
      char_post = create(:post, user: user, character: character)
      reply = create(:reply, user: user, character: character)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, alias_dropdown: calias.id }
      end

      expect(char_post.reload.character_id).to eq(other_char.id)
      expect(reply.reload.character_id).to eq(other_char.id)
      expect(char_post.reload.character_alias_id).to eq(calias.id)
      expect(reply.reload.character_alias_id).to eq(calias.id)
    end

    it "filters to selected posts if given" do
      user = create(:user)
      character = create(:character, user: user)
      other_char = create(:character, user: user)
      char_post = create(:post, user: user, character: character)
      char_reply = create(:reply, user: user, character: character)
      other_post = create(:post, user: user, character: character)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: {
          id: character.id,
          icon_dropdown: other_char.id,
          post_ids: [char_post.id, char_reply.post.id]
        }
      end
      expect(response).to redirect_to(character_path(character))
      expect(flash[:success]).to eq('All uses of this character in the specified posts will be replaced.')

      expect(char_post.reload.character_id).to eq(other_char.id)
      expect(char_reply.reload.character_id).to eq(other_char.id)
      expect(other_post.reload.character_id).to eq(character.id)
    end

    it "filters to alias if given" do
      user = create(:user)
      character = create(:character, user: user)
      other_char = create(:character, user: user)
      calias = create(:alias, character: character)
      char_post = create(:post, user: user, character: character)
      char_reply = create(:reply, user: user, character: character, character_alias_id: calias.id)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, orig_alias: calias.id }
      end

      expect(char_post.reload.character_id).to eq(character.id)
      expect(char_reply.reload.character_id).to eq(other_char.id)
    end

    it "filters to nil if given" do
      user = create(:user)
      character = create(:character, user: user)
      other_char = create(:character, user: user)
      calias = create(:alias, character: character)
      char_post = create(:post, user: user, character: character)
      char_reply = create(:reply, user: user, character: character, character_alias_id: calias.id)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, orig_alias: '' }
      end

      expect(char_post.reload.character_id).to eq(other_char.id)
      expect(char_reply.reload.character_id).to eq(character.id)
    end

    it "does not filter if all given" do
      user = create(:user)
      character = create(:character, user: user)
      other_char = create(:character, user: user)
      calias = create(:alias, character: character)
      char_post = create(:post, user: user, character: character)
      char_reply = create(:reply, user: user, character: character, character_alias_id: calias.id)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, orig_alias: 'all' }
      end

      expect(char_post.reload.character_id).to eq(other_char.id)
      expect(char_reply.reload.character_id).to eq(other_char.id)
    end
  end

  describe "GET search" do
    it 'works logged in' do
      login
      get :search
      expect(response).to have_http_status(200)
      expect(assigns(:users)).to be_empty
      expect(assigns(:templates)).to be_empty
    end

    it 'works logged out' do
      get :search
      expect(response).to have_http_status(200)
      expect(assigns(:users)).to be_empty
    end

    it 'searches author' do
      author = create(:user)
      found = create(:character, user: author)
      create(:character) # notfound
      get :search, params: { commit: true, author_id: author.id }
      expect(response).to have_http_status(200)
      expect(assigns(:users)).to match_array([author])
      expect(assigns(:search_results)).to match_array([found])
    end

    it "doesn't search missing author" do
      character = create(:template_character)
      get :search, params: { commit: true, author_id: 9999 }
      expect(response).to have_http_status(200)
      expect(flash[:error]).to eq('The specified author could not be found.')
      expect(assigns(:users)).to be_empty
      expect(assigns(:search_results)).to match_array([character])
    end

    it "sets templates by author" do
      author = create(:user)
      template2 = create(:template, user: author, name: 'b')
      template = create(:template, user: author, name: 'a')
      template3 = create(:template, user: author, name: 'c')
      create(:template)
      get :search, params: { commit: true, author_id: author.id }
      expect(assigns(:templates)).to eq([template, template2, template3])
    end

    it "doesn't search missing template" do
      character = create(:template_character)
      get :search, params: { commit: true, template_id: 9999 }
      expect(response).to have_http_status(200)
      expect(flash[:error]).to eq('The specified template could not be found.')
      expect(assigns(:templates)).to be_empty
      expect(assigns(:search_results)).to match_array([character])
    end

    it "doesn't search author/template mismatch" do
      character = create(:template_character)
      character2 = create(:character)
      get :search, params: { commit: true, template_id: character.template_id, author_id: character2.user_id }
      expect(response).to have_http_status(200)
      expect(flash[:error]).to eq('The specified author and template do not match; template filter will be ignored.')
      expect(assigns(:templates)).to be_empty
      expect(assigns(:search_results)).to match_array([character2])
    end

    it 'searches template' do
      author = create(:user)
      template = create(:template, user: author)
      found = create(:character, user: author, template: template)
      create(:character, user: author, template: create(:template, user: author)) # notfound
      get :search, params: { commit: true, template_id: template.id }
      expect(response).to have_http_status(200)
      expect(assigns(:templates)).to match_array([template])
      expect(assigns(:search_results)).to match_array([found])
    end

    context "searching" do
      before(:each) do
        @name = create(:character, name: 'a', screenname: 'b', nickname: 'c')
        @nickname = create(:character, name: 'b', screenname: 'c', nickname: 'a')
        @screenname = create(:character, name: 'c', screenname: 'a', nickname: 'b')
      end

      it "searches names correctly" do
        get :search, params: { commit: true, name: 'a', search_name: true }
        expect(assigns(:search_results)).to match_array([@name])
      end

      it "searches screenname correctly" do
        get :search, params: { commit: true, name: 'a', search_screenname: true }
        expect(assigns(:search_results)).to match_array([@screenname])
      end

      it "searches nickname correctly" do
        get :search, params: { commit: true, name: 'a', search_nickname: true }
        expect(assigns(:search_results)).to match_array([@nickname])
      end

      it "searches name + screenname correctly" do
        get :search, params: { commit: true, name: 'a', search_name: true, search_screenname: true }
        expect(assigns(:search_results)).to match_array([@name, @screenname])
      end

      it "searches name + nickname correctly" do
        get :search, params: { commit: true, name: 'a', search_name: true, search_nickname: true }
        expect(assigns(:search_results)).to match_array([@name, @nickname])
      end

      it "searches nickname + screenname correctly" do
        get :search, params: { commit: true, name: 'a', search_nickname: true, search_screenname: true }
        expect(assigns(:search_results)).to match_array([@nickname, @screenname])
      end

      it "searches all correctly" do
        get :search, params: {
          commit: true,
          name: 'a',
          search_name: true,
          search_screenname: true,
          search_nickname: true
        }
        expect(assigns(:search_results)).to match_array([@name, @screenname, @nickname])
      end

      it "orders results correctly" do
        template = create(:template)
        user = template.user
        char4 = create(:character, user: user, template: template, name: 'd')
        char2 = create(:character, user: user, name: 'b')
        char1 = create(:character, user: user, template: template, name: 'a')
        char5 = create(:character, user: user, name: 'e')
        char3 = create(:character, user: user, name: 'c')
        get :search, params: { commit: true, author_id: user.id }
        expect(assigns(:search_results)).to eq([char1, char2, char3, char4, char5])
      end

      it "paginates correctly" do
        user = create(:user)
        26.times do |i|
          create(:character, user: user, name: "character#{i}")
        end
        get :search, params: { commit: true, author_id: user.id }
        expect(assigns(:search_results).length).to eq(25)
      end
    end
  end

  describe "POST duplicate" do
    it "requires login" do
      post :duplicate, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq('You must be logged in to view that page.')
    end

    it "requires valid character id" do
      user_id = login
      post :duplicate, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires character with permissions" do
      user_id = login
      post :duplicate, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq('You do not have permission to modify this character.')
    end

    it "succeeds" do
      user = create(:user)
      template = create(:template, user: user)
      icon = create(:icon, user: user)
      gallery = create(:gallery, icons: [icon], user: user)
      group = create(:gallery_group)
      gallery2 = create(:gallery, gallery_groups: [group], user: user)
      gallery3 = create(:gallery, gallery_groups: [group], user: user)
      character = create(:character, template: template, galleries: [gallery, gallery2], gallery_groups: [group], default_icon: icon, user: user)
      calias = create(:alias, character: character)
      char_post = create(:post, character: character, user: user)
      char_reply = create(:reply, character: character, user: user)
      character.settings << create(:setting)

      character.reload

      expect(character.galleries).to match_array([gallery, gallery2, gallery3])
      expect(character.ungrouped_gallery_ids).to match_array([gallery.id, gallery2.id])
      expect(character.gallery_groups).to match_array([group])

      login_as(user)
      expect do
        post :duplicate, params: { id: character.id }
      end.to not_change {
        [Template.count, Gallery.count, Icon.count, Reply.count, Post.count, Tag.count]
      }.and change { Character.count }.by(1).and change { CharactersGallery.count }.by(3).and change { CharacterTag.count }.by(2)

      dupe = Character.last
      character.reload
      expect(response).to redirect_to(edit_character_url(dupe))
      expect(flash[:success]).to eq('Character duplicated. You are now editing the new character.')

      expect(dupe).not_to eq(character)

      # check all attrs but id, created_at and updated_at are same
      dup_attrs = dupe.attributes.clone
      char_attrs = character.attributes.clone
      ['id', 'created_at', 'updated_at'].each do |val|
        dup_attrs.delete(val)
        char_attrs.delete(val)
      end
      expect(dup_attrs).to eq(char_attrs)

      # check character associations aren't changed
      expect(character.template).to eq(template)
      expect(character.galleries).to match_array([gallery, gallery2, gallery3])
      expect(character.ungrouped_gallery_ids).to match_array([gallery.id, gallery2.id])
      expect(character.gallery_groups).to match_array([group])
      expect(character.default_icon).to eq(icon)
      expect(character.user).to eq(user)
      expect(character.aliases.map(&:name)).to eq([calias.name])

      # check duplicate has appropriate associations
      expect(dupe.template).to eq(template)
      expect(dupe.galleries).to match_array([gallery, gallery2, gallery3])
      expect(dupe.ungrouped_gallery_ids).to match_array([gallery.id, gallery2.id])
      expect(dupe.gallery_groups).to match_array([group])
      expect(dupe.default_icon).to eq(icon)
      expect(dupe.user).to eq(user)
      expect(dupe.aliases.map(&:name)).to eq([calias.name])

      # check old posts and replies have old attributes
      char_post.reload
      char_reply.reload
      expect(char_post.character).to eq(character)
      expect(char_reply.character).to eq(character)
    end

    it "handles unexpected failure" do
      character = create(:character)
      login_as(character.user)
      character.update_columns(default_icon_id: create(:icon).id) # rubocop:disable Rails/SkipsModelValidations
      expect(character).not_to be_valid
      expect{ post :duplicate, params: { id: character.id } }.to not_change { Character.count }
      expect(response).to redirect_to(character_path(character))
      expect(flash[:error][:message]).to eq('Character could not be duplicated because of the following problems:')
      expect(flash[:error][:array]).to eq(['Default icon must be yours'])
    end
  end

  describe "#character_split" do
    context "when logged out" do
      it "works by default" do
        expect(controller.send(:character_split)).to eq('template')
      end

      it "can be overridden with a parameter" do
        controller.params[:character_split] = 'none'
        expect(session[:character_split]).to be_nil
        expect(controller.send(:character_split)).to eq('none')
        expect(session[:character_split]).to eq('none')
      end

      it "uses session variable if it exists" do
        session[:character_split] = 'none'
        expect(controller.send(:character_split)).to eq('none')
      end
    end

    context "when logged in" do
      it "works by default" do
        login
        expect(controller.send(:character_split)).to eq('template')
      end

      it "uses account default if different" do
        user = create(:user, default_character_split: 'none')
        login_as(user)
        expect(controller.send(:character_split)).to eq('none')
      end

      it "is not overridden by session" do
        # also does not modify user default
        user = create(:user, default_character_split: 'none')
        login_as(user)
        session[:character_split] = 'template'
        expect(controller.send(:character_split)).to eq('none')
        expect(user.reload.default_character_split).to eq('none')
      end

      it "can be overridden by params" do
        # also does not modify user default
        user = create(:user, default_character_split: 'none')
        login_as(user)
        controller.params[:character_split] = 'template'
        expect(controller.send(:character_split)).to eq('template')
        expect(user.reload.default_character_split).to eq('none')
      end
    end
  end

  describe "#editor_setup" do
    it "orders characters correctly" do
      user = create(:user)
      login_as(user)
      template4 = create(:template, user: user, name: "d")
      template2 = create(:template, user: user, name: "b")
      template1 = create(:template, user: user, name: "a")
      template3 = create(:template, user: user, name: "c")
      controller.send(:editor_setup)
      expect(assigns(:templates)).to eq([template1, template2, template3, template4])
    end

    skip "has more tests"
  end
end
