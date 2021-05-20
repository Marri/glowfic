RSpec.describe CharactersController do
  include ActiveJob::TestHelper

  describe "GET index" do
    let(:user) { create(:user) }

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
      get :index, params: { user_id: user.id }
      expect(response.status).to eq(200)
    end

    it "succeeds when logged in" do
      login
      get :index
      expect(response.status).to eq(200)
    end

    it "succeeds with an id when logged in" do
      login
      get :index, params: { user_id: user.id }
      expect(response.status).to eq(200)
    end

    it "does something with character groups" do
      skip "Character groups need to be refactored"
    end

    context "with render_views" do
      render_views
      before(:each) do
        create(:character, user: user)
        create(:template_character, user: user)
      end

      it "successfully renders the page in template group" do
        get :index, params: { user_id: user.id, character_split: 'template' }
        expect(response.status).to eq(200)
      end

      it "successfully renders the page with no group" do
        get :index, params: { user_id: user.id, character_split: 'none' }
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
    let(:user) { create(:user) }
    let(:template) { create(:template, user: user) }

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
      login_as(user)
      get :new, params: { template_id: template.id }
      expect(response.status).to eq(200)
      expect(assigns(:character).template).to eq(template)
    end

    context "with views" do
      render_views
      it "sets correct variables" do
        templates = create_list(:template, 2, user: user)
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
    let(:user) { create(:user) }
    let(:gallery) { create(:gallery, user: user) }

    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "fails with missing params" do
      login
      post :create
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Your character could not be saved.")
    end

    it "fails with invalid params" do
      login
      post :create, params: { character: {} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Your character could not be saved.")
    end

    it "succeeds when valid" do
      expect(Character.count).to eq(0)
      test_name = 'Test character'
      template = create(:template, user: user)
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
      expect(flash[:success]).to eq("Character saved successfully.")
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
        group = create(:gallery_group)
        group_gallery = create(:gallery, user: user, gallery_groups: [group])
        templates = create_list(:template, 2, user: user)
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
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires valid character logged out" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires valid character logged in" do
      login_as(user)
      get :show, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "should succeed when logged out" do
      get :show, params: { id: character.id }
      expect(response.status).to eq(200)
    end

    it "should succeed when logged in" do
      login
      get :show, params: { id: character.id }
      expect(response.status).to eq(200)
    end

    it "should set correct variables" do
      create_list(:post, 26, character: character, user: user)
      get :show, params: { id: character.id }
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq(character.name)
      expect(assigns(:posts).size).to eq(25)
      expect(assigns(:posts)).to match_array(Post.where(character_id: character.id).ordered.limit(25))
    end

    it "should only show visible posts" do
      create(:post, character: character, user: character.user, privacy: :private)
      get :show, params: { id: character.id }
      expect(assigns(:posts)).to be_blank
    end

    it "orders recent posts" do
      post3 = create(:post)
      post1 = create(:post, user: user, character: character)
      post4 = create(:post, user: user, character: character)
      post2 = create(:post)
      create(:reply, post: post4)
      create(:reply, post: post3, user: user, character: character)
      create(:reply, post: post2, user: user, character: character)
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
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character id" do
      login_as(user)
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires character with permissions" do
      login_as(user)
      get :edit, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("You do not have permission to edit that character.")
    end

    it "succeeds when logged in" do
      login_as(user)
      get :edit, params: { id: character.id }
      expect(response.status).to eq(200)
    end

    context "with views" do
      render_views
      it "sets correct variables" do
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

      context "works for moderator" do
        let!(:template) { create(:template, user: user) }

        before(:each) { login_as(create(:mod_user)) }

        it "works for moderator with untemplated character" do
          get :edit, params: { id: character.id }

          expect(assigns(:page_title)).to eq("Edit Character: #{character.name}")
          expect(controller.gon.character_id).to eq(character.id)
          expect(controller.gon.user_id).to eq(user.id)
          expect(assigns(:templates)).to match_array([template])
        end

        it "works for moderator with templated character" do
          character = create(:template_character, user: user)

          get :edit, params: { id: character.id }

          expect(assigns(:page_title)).to eq("Edit Character: #{character.name}")
          expect(controller.gon.character_id).to eq(character.id)
          expect(controller.gon.user_id).to eq(user.id)
          expect(assigns(:templates)).to match_array([character.template, template])
        end
      end
    end
  end

  describe "PUT update" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character id" do
      login_as(user)
      put :update, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires character with permissions" do
      login_as(user)
      put :update, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("You do not have permission to edit that character.")
    end

    it "fails with invalid params" do
      login_as(user)
      put :update, params: { id: character.id, character: {name: ''} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Your character could not be saved.")
    end

    it "fails with invalid template params" do
      login_as(user)
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
      expect(flash[:error][:message]).to eq("Your character could not be saved.")
      expect(character.reload.name).not_to eq(new_name)
    end

    it "requires notes from moderators" do
      login_as(create(:mod_user))
      put :update, params: { id: character.id, character: { name: 'b' } }
      expect(response).to render_template(:edit)
      expect(flash[:error]).to eq('You must provide a reason for your moderator edit.')
    end

    it "stores note from moderators" do
      Character.auditing_enabled = true
      login_as(create(:admin_user))
      put :update, params: { id: character.id, character: { name: 'b', audit_comment: 'note' } }
      expect(flash[:success]).to eq("Character saved successfully.")
      expect(character.reload.name).to eq('b')
      expect(character.audits.last.comment).to eq('note')
      Character.auditing_enabled = false
    end

    context "complex characters" do
      let(:template) { create(:template, user: user) }
      let(:gallery) { create(:gallery, user: user) }
      let(:setting) { create(:setting, name: 'Another World') }
      let(:params) do
        {
          id: character.id,
          character: {
            nickname: 'TemplateName',
            screenname: 'a-new-test',
            setting_ids: [setting.id],
            template_id: template.id,
            pb: 'Actor',
            description: 'Description',
            ungrouped_gallery_ids: [gallery.id]
          }
        }
      end

      before(:each) { login_as(user) }

      it "succeeds when valid" do
        new_name = character.name + 'aaa'
        params[:character][:name] = new_name

        put :update, params: params

        expect(response).to redirect_to(assigns(:character))
        expect(flash[:success]).to eq("Character saved successfully.")
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
        old_name = character.name

        params[:character][:name] = ''

        put :update, params: params

        expect(response.status).to eq(200)
        expect(flash[:error][:message]).to eq("Your character could not be saved.")
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
    end

    it "creates new templates when specified" do
      expect(Template.count).to eq(0)
      login_as(user)
      put :update, params: { id: character.id, new_template: '1', character: {template_attributes: {name: 'Test'}} }
      expect(Template.count).to eq(1)
      expect(Template.first.name).to eq('Test')
      expect(character.reload.template_id).to eq(Template.first.id)
    end

    context "with gallery groups" do
      let(:group) { create(:gallery_group) }
      let(:gallery) { create(:gallery, gallery_groups: [group], user: user) }

      before(:each) { login_as(user) }

      it "adds galleries by groups" do
        gallery

        put :update, params: { id: character.id, character: {gallery_group_ids: [group.id]} }

        expect(flash[:success]).to eq('Character saved successfully.')
        character.reload
        expect(character.gallery_groups).to match_array([group])
        expect(character.galleries).to match_array([gallery])
        expect(character.ungrouped_gallery_ids).to be_blank
        expect(character.characters_galleries.first).to be_added_by_group
      end

      it "removes gallery only if not shared between groups" do
        group1 = create(:gallery_group)
        group2 = create(:gallery_group)
        group3 = create(:gallery_group)
        group4 = create(:gallery_group)
        gallery1 = create(:gallery, gallery_groups: [group1, group2], user: user)
        gallery2 = create(:gallery, gallery_groups: [group3, group4], user: user)
        character = create(:character, gallery_groups: [group1, group3, group4], user: user)

        put :update, params: { id: character.id, character: {gallery_group_ids: [group2.id, group4.id]} }

        expect(flash[:success]).to eq('Character saved successfully.')
        character.reload
        expect(character.gallery_groups).to match_array([group2, group4])
        expect(character.galleries).to match_array([gallery1, gallery2])
        expect(character.ungrouped_gallery_ids).to be_blank
        expect(character.characters_galleries.map(&:added_by_group)).to eq([true, true])
      end

      it "does not remove gallery if tethered by group" do
        gallery
        character = create(:character, gallery_groups: [group], ungrouped_gallery_ids: [gallery.id], user: user)
        expect(character.characters_galleries.first).not_to be_added_by_group

        put :update, params: {
          id: character.id,
          character: {
            ungrouped_gallery_ids: [''],
            gallery_group_ids: [group.id]
          }
        }
        expect(flash[:success]).to eq('Character saved successfully.')
        character.reload
        expect(character.gallery_groups).to match_array([group])
        expect(character.galleries).to match_array([gallery])
        expect(character.ungrouped_gallery_ids).to be_blank
        expect(character.characters_galleries.first).to be_added_by_group
      end

      it "works when adding both group and gallery" do
        put :update, params: {
          id: character.id,
          character: {
            gallery_group_ids: [group.id],
            ungrouped_gallery_ids: [gallery.id]
          }
        }

        expect(flash[:success]).to eq('Character saved successfully.')
        character.reload
        expect(character.gallery_groups).to match_array([group])
        expect(character.galleries).to match_array([gallery])
        expect(character.ungrouped_gallery_ids).to eq([gallery.id])
        expect(character.characters_galleries.first).not_to be_added_by_group
      end

      it "does not add another user's galleries" do
        create(:gallery, gallery_groups: [group])

        put :update, params: { id: character.id, character: {gallery_group_ids: [group.id]} }
        expect(flash[:success]).to eq('Character saved successfully.')
        character.reload
        expect(character.gallery_groups).to match_array([group])
        expect(character.galleries).to be_blank
      end

      it "removes untethered galleries when group goes" do
        gallery
        character = create(:character, gallery_groups: [group], user: user)

        login_as(user)
        put :update, params: { id: character.id, character: {gallery_group_ids: ['']} }
        expect(flash[:success]).to eq('Character saved successfully.')
        character.reload
        expect(character.gallery_groups).to eq([])
        expect(character.galleries).to eq([])
      end
    end

    context "with views" do
      render_views

      before(:each) { login_as(user) }

      it "sets correct variables when invalid" do
        group = create(:gallery_group)
        gallery = create(:gallery, user: user, gallery_groups: [group])
        character = create(:character, user: user, gallery_groups: [group])
        templates = Array.new(2) { create(:template, user: user) }
        create(:template)

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
      g1 = create(:gallery, user: user)
      g2 = create(:gallery, user: user)
      character.galleries << g1
      character.galleries << g2
      g1_cg = CharactersGallery.find_by(gallery_id: g1.id)
      g2_cg = CharactersGallery.find_by(gallery_id: g2.id)
      expect(g1_cg.section_order).to eq(0)
      expect(g2_cg.section_order).to eq(1)
      login_as(user)

      put :update, params: { id: character.id, character: {ungrouped_gallery_ids: [g2.id.to_s]} }

      expect(character.reload.galleries.pluck(:id)).to eq([g2.id])
      expect(g2_cg.reload.section_order).to eq(0)
    end

    it "orders settings by default" do
      login_as(user)
      setting1 = create(:setting)
      setting3 = create(:setting)
      setting2 = create(:setting)

      put :update, params: {
        id: character.id,
        character: {setting_ids: [setting1, setting2, setting3].map(&:id)}
      }

      expect(flash[:success]).to eq('Character saved successfully.')
      expect(character.settings).to eq([setting1, setting2, setting3])
    end

    it "orders gallery groups by default" do
      login_as(user)
      group4 = create(:gallery_group, user: user)
      group1 = create(:gallery_group, user: user)
      group3 = create(:gallery_group, user: user)
      group2 = create(:gallery_group, user: user)
      put :update, params: {
        id: character.id,
        character: {gallery_group_ids: [group1, group2, group3, group4].map(&:id)}
      }
      expect(flash[:success]).to eq('Character saved successfully.')
      expect(character.gallery_groups).to eq([group1, group2, group3, group4])
    end
  end

  describe "GET facecasts" do
    let(:chars) { Array.new(3) { create(:character, pb: SecureRandom.urlsafe_base64) } }
    let(:temp_chars) { Array.new(3) { create(:template_character, pb: SecureRandom.urlsafe_base64) } }
    let(:all_chars) { chars + temp_chars }

    it "does not require login" do
      get :facecasts
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("Facecasts")
    end

    it "sets correct variables for facecast name sort" do
      chars
      get :facecasts
      pbs = assigns(:pbs).map(&:pb)
      expect(pbs).to match_array(chars.map(&:pb))
    end

    it "sets correct variables for character name sort: character only" do
      chars
      get :facecasts, params: { sort: 'name' }
      names = assigns(:pbs).map(&:item_name)
      expect(names).to match_array(chars.map(&:name))
    end

    it "sets correct variables for character name sort: template only" do
      temp_chars
      get :facecasts, params: { sort: 'name' }
      names = assigns(:pbs).map(&:item_name)
      expect(names).to match_array(temp_chars.map(&:template).map(&:name))
    end

    it "sets correct variables for character name sort: character and template mixed" do
      all_chars
      get :facecasts, params: { sort: 'name' }
      names = assigns(:pbs).map(&:item_name)
      expect(names).to match_array(all_chars.map { |c| (c.template || c).name })
    end

    it "sets correct variables for writer sort" do
      all_chars
      get :facecasts, params: { sort: 'writer' }
      user_ids = assigns(:pbs).map(&:user_id)
      expect(user_ids).to match_array(all_chars.map(&:user).map(&:id))
    end
  end

  describe "DELETE destroy" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user)}

    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      login_as(user)
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires permission" do
      login_as(user)
      delete :destroy, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("You do not have permission to edit that character.")
    end

    it "succeeds" do
      login_as(user)
      delete :destroy, params: { id: character.id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:success]).to eq("Character deleted successfully.")
      expect(Character.find_by_id(character.id)).to be_nil
    end

    it "handles destroy failure" do
      post = create(:post, user: user, character: character)
      login_as(user)
      expect_any_instance_of(Character).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: character.id }
      expect(response).to redirect_to(character_url(character))
      expect(flash[:error]).to eq({message: "Character could not be deleted.", array: []})
      expect(post.reload.character).to eq(character)
    end
  end

  describe "GET replace" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires login" do
      get :replace, params: { id: character.id }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq('You must be logged in to view that page.')
    end

    it "requires valid character" do
      login_as(user)
      get :replace, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires own character" do
      login_as(user)
      get :replace, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq('You do not have permission to edit that character.')
    end

    it "sets correct variables" do
      default_icon = create(:icon, user: user)
      other_char = create(:character, user: user, default_icon: default_icon)
      calias = create(:alias, character: other_char)
      char_post = create(:post, user: user, character: character)
      create(:reply, user: user, post: char_post, character: character)
      create(:post)
      char_reply2 = create(:reply, user: user, character: character)

      login_as(user)
      get :replace, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq('Replace Character: ' + character.name)

      expect(controller.gon.gallery[other_char.id][:url]).to eq(other_char.default_icon.url)
      expect(controller.gon.gallery[other_char.id][:aliases]).to eq([calias.as_json])
      expect(assigns(:posts)).to match_array([char_post, char_reply2.post])
    end

    context "with template" do
      let(:template) { create(:template, user: user) }
      let(:character) { create(:character, template: template, user: user) }

      before(:each) do
        login_as(user)
        create(:character, user: user)
      end

      it "sets alts correctly" do
        alts = create_list(:character, 5, user: user, template: template)

        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Replace Character: ' + character.name)
        expect(assigns(:alts)).to match_array(alts)
        expect(assigns(:alt_dropdown).length).to eq(alts.length)
      end

      it "includes character if no others in template" do
        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:alts)).to match_array([character])
      end
    end

    context "without template" do
      before(:each) do
        create(:template_character, user: user)
        login_as(user)
      end

      it "sets alts correctly" do
        alts = create_list(:character, 5, user: user)

        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:page_title)).to eq('Replace Character: ' + character.name)
        expect(assigns(:alts)).to match_array(alts)
        expect(assigns(:alt_dropdown).length).to eq(alts.length)
      end

      it "includes character if no others in template" do
        login_as(user)
        get :replace, params: { id: character.id }
        expect(response).to have_http_status(200)
        expect(assigns(:alts)).to match_array([character])
      end
    end
  end

  describe "POST do_replace" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }
    let(:other_char) { create(:character, user: user) }

    it "requires login" do
      post :do_replace, params: { id: character.id }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq('You must be logged in to view that page.')
    end

    it "requires valid character" do
      login_as(user)
      post :do_replace, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires own character" do
      login_as(user)
      post :do_replace, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq('You do not have permission to edit that character.')
    end

    it "requires valid other character" do
      login_as(user)
      post :do_replace, params: { id: character.id, icon_dropdown: -1 }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires other character to be yours if present" do
      other_char = create(:character)
      login_as(user)
      post :do_replace, params: { id: character.id, icon_dropdown: other_char.id }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('That is not your character.')
    end

    it "requires valid new alias if parameter provided" do
      login_as(user)
      post :do_replace, params: { id: character.id, alias_dropdown: -1 }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid new alias.')
    end

    it "requires matching new alias if parameter provided" do
      calias = create(:alias)
      login_as(user)
      post :do_replace, params: { id: character.id, alias_dropdown: calias.id, icon_dropdown: other_char.id }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid new alias.')
    end

    it "requires valid old alias if parameter provided" do
      login_as(user)
      post :do_replace, params: { id: character.id, orig_alias: -1 }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid old alias.')
    end

    it "requires matching old alias if parameter provided" do
      calias = create(:alias)
      login_as(user)
      post :do_replace, params: { id: character.id, orig_alias: calias.id }
      expect(response).to redirect_to(replace_character_path(character))
      expect(flash[:error]).to eq('Invalid old alias.')
    end

    context "with content" do
      let!(:char_post) { create(:post, user: user, character: character) }
      let!(:reply) { create(:reply, user: user, character: character) }
      let(:calias) { create(:alias, character: character) }

      before(:each) { login_as(user) }

      context "with audits enabled" do
        before(:each) { Reply.auditing_enabled = true }
        after(:each) { Reply.auditing_enabled = false }

        it "succeeds with valid other character" do
          reply_post_char = reply.post.character_id

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
        perform_enqueued_jobs(only: UpdateModelJob) do
          post :do_replace, params: { id: character.id }
        end
        expect(response).to redirect_to(character_path(character))
        expect(flash[:success]).to eq('All uses of this character will be replaced.')

        expect(char_post.reload.character_id).to be_nil
        expect(reply.reload.character_id).to be_nil
      end

      it "succeeds with alias" do
        calias = create(:alias, character: other_char)

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
        other_post = create(:post, user: user, character: character)

        perform_enqueued_jobs(only: UpdateModelJob) do
          post :do_replace, params: {
            id: character.id,
            icon_dropdown: other_char.id,
            post_ids: [char_post.id, reply.post.id]
          }
        end
        expect(response).to redirect_to(character_path(character))
        expect(flash[:success]).to eq('All uses of this character in the specified posts will be replaced.')

        expect(char_post.reload.character_id).to eq(other_char.id)
        expect(reply.reload.character_id).to eq(other_char.id)
        expect(other_post.reload.character_id).to eq(character.id)
      end

      it "filters to alias if given" do
        char_reply = create(:reply, user: user, character: character, character_alias_id: calias.id)

        perform_enqueued_jobs(only: UpdateModelJob) do
          post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, orig_alias: calias.id }
        end

        expect(char_post.reload.character_id).to eq(character.id)
        expect(char_reply.reload.character_id).to eq(other_char.id)
      end

      it "filters to nil if given" do
        char_reply = create(:reply, user: user, character: character, character_alias_id: calias.id)

        perform_enqueued_jobs(only: UpdateModelJob) do
          post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, orig_alias: '' }
        end

        expect(char_post.reload.character_id).to eq(other_char.id)
        expect(char_reply.reload.character_id).to eq(character.id)
      end

      it "does not filter if all given" do
        char_reply = create(:reply, user: user, character: character, character_alias_id: calias.id)

        perform_enqueued_jobs(only: UpdateModelJob) do
          post :do_replace, params: { id: character.id, icon_dropdown: other_char.id, orig_alias: 'all' }
        end

        expect(char_post.reload.character_id).to eq(other_char.id)
        expect(char_reply.reload.character_id).to eq(other_char.id)
      end
    end
  end

  describe "GET search" do
    let(:author) { create(:user) }

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
    let(:user) { create(:user) }

    it "requires login" do
      post :duplicate, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq('You must be logged in to view that page.')
    end

    it "requires valid character id" do
      login_as(user)
      post :duplicate, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq('Character could not be found.')
    end

    it "requires character with permissions" do
      login_as(user)
      post :duplicate, params: { id: create(:character).id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq('You do not have permission to edit that character.')
    end

    it "succeeds" do
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
      expect { post :duplicate, params: { id: character.id } }
        .to not_change { [Template.count, Gallery.count, Icon.count, Reply.count, Post.count, Tag.count] }
        .and change { Character.count }.by(1)
        .and change { CharactersGallery.count }.by(3)
        .and change { CharacterTag.count }.by(2)

      dupe = Character.last
      character.reload
      expect(response).to redirect_to(edit_character_url(dupe))
      expect(flash[:success]).to eq('Character duplicated successfully. You are now editing the new character.')

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
      character = create(:character, user: user)
      login_as(user)
      character.update_columns(default_icon_id: create(:icon).id) # rubocop:disable Rails/SkipsModelValidations
      expect(character).not_to be_valid
      expect{ post :duplicate, params: { id: character.id } }.to not_change { Character.count }
      expect(response).to redirect_to(character_path(character))
      expect(flash[:error][:message]).to eq('Character could not be duplicated.')
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
