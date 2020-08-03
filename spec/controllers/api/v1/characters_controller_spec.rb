RSpec.describe Api::V1::CharactersController do
  describe "GET index" do
    shared_examples_for "index.json" do |in_doc|
      it "should support no search", show_in_doc: in_doc do
        char = create(:character)
        get :index
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "should support search" do
        char = create(:character, name: 'search')
        create(:character, name: 'no') # char2
        get :index, params: { q: 'se' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "requires valid post id if provided", show_in_doc: in_doc do
        create(:character)
        get :index, params: { post_id: -1 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'].size).to eq(1)
        expect(response.json['errors'][0]['message']).to eq("Post could not be found.")
      end

      it "requires valid template id if provided", show_in_doc: in_doc do
        create(:character)
        get :index, params: { template_id: 999 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'].size).to eq(1)
        expect(response.json['errors'][0]['message']).to eq("Template could not be found.")
      end

      it "requires valid user id if provided", show_in_doc: in_doc do
        character = create(:character)
        get :index, params: { user_id: character.user.id + 1 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'].size).to eq(1)
        expect(response.json['errors'][0]['message']).to eq("User could not be found.")
      end

      it "requires valid includes if provided", show_in_doc: in_doc do
        create(:character)
        get :index, params: { includes: ['invalid'] }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'].size).to eq(1)
        expected = "Invalid parameter 'includes' value ['invalid']: Must be an array of ['default_icon', 'aliases', 'nickname']"
        expect(response.json['errors'][0]['message']).to eq(expected)
      end

      it "requires post with permission", show_in_doc: in_doc do
        post = create(:post, privacy: :private, with_character: true)
        get :index, params: { post_id: post.id }
        expect(response).to have_http_status(:forbidden)
        expect(response.json['errors'].size).to eq(1)
        expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
      end

      it "filters by post" do
        char = create(:character)
        create(:character) # char2
        post = create(:post, character: char, user: char.user)
        get :index, params: { post_id: post.id }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "filters by template" do
        template = create(:template)
        char = create(:character, template: template)
        create(:character)
        get :index, params: { template_id: template.id }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "filters by templateless" do
        template = create(:template)
        create(:character, template: template)
        char = create(:character)
        get :index, params: { template_id: '0' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "filters by user id" do
        char = create(:character)
        char2 = create(:character)
        api_login_as(char2.user)
        get :index, params: { user_id: char.user_id }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "matches lowercase" do
        char = create(:character, name: 'Upcase')
        get :index, params: { q: 'upcase' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "matches uppercase" do
        char = create(:character, name: 'downcase')
        get :index, params: { q: 'DOWNcase' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "matches nickname" do
        char = create(:character, name: 'a', nickname: 'b', screenname: 'c')
        get :index, params: { q: 'b' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "matches screenname" do
        char = create(:character, name: 'a', nickname: 'b', screenname: 'c')
        get :index, params: { q: 'c' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end

      it "matches midword" do
        char = create(:character, name: 'abcdefg')
        get :index, params: { q: 'cde' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(char.as_json(include: [:selector_name]).stringify_keys)
      end
    end

    context "when logged in" do
      before(:each) { api_login }

      it_behaves_like "index.json", false
    end

    context "when logged out" do
      it_behaves_like "index.json", true
    end
  end

  describe "GET show" do
    it "requires valid character", :show_in_doc do
      get :show, params: { id: -1 }
      expect(response).to have_http_status(404)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("Character could not be found.")
    end

    it "succeeds with valid character" do
      character = create(:character)
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['name']).to eq(character.name)
    end

    it "succeeds for logged in users with valid character" do
      character = create(:character)
      api_login
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['name']).to eq(character.name)
    end

    it "has single gallery when present" do
      character = create(:character)
      character.galleries << create(:gallery, user: character.user)
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['galleries'].size).to eq(1)
    end

    it "has single gallery when icon present" do
      character = create(:character)
      character.default_icon = create(:icon, user: character.user)
      character.save!
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['galleries'].size).to eq(1)
    end

    it "returns icons in keyword order" do
      gallery = create(:gallery)
      gallery.icons << create(:icon, keyword: 'zzz', user: gallery.user)
      gallery.icons << create(:icon, keyword: 'yyy', user: gallery.user)
      gallery.icons << create(:icon, keyword: 'xxx', user: gallery.user)
      expect(gallery.icons.pluck(:keyword)).to eq(['xxx', 'yyy', 'zzz'])
      character = create(:character, user: gallery.user)
      character.galleries << gallery
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['galleries'].size).to eq(1)
      expect(response.json['galleries'][0]['icons'].map { |i| i['keyword'] }).to eq(['xxx', 'yyy', 'zzz'])
    end

    it "has associations when present", :show_in_doc do
      character = create(:character)
      calias = create(:alias, character: character)
      character.galleries << create(:gallery, user: character.user, icon_count: 2)
      character.galleries << create(:gallery, user: character.user, icon_count: 1)
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['galleries'].size).to eq(2)
      expect(response.json['aliases'].size).to eq(1)
      expect(response.json['aliases'].first['id']).to eq(calias.id)
    end

    it "has galleries when icon_picker_grouping is false" do
      user = create(:user, icon_picker_grouping: false)
      character = create(:character, user: user)
      character.galleries << create(:gallery, user: user)
      character.galleries << create(:gallery, user: user)
      character.galleries[0].icons << create(:icon, user: user)
      character.galleries[1].icons << create(:icon, user: user)
      get :show, params: { id: character.id }
      expect(response).to have_http_status(200)
      expect(response.json['galleries'].size).to eq(1)
    end

    it "requires post to exist when provided a post_id", :show_in_doc do
      character = create(:character)
      get :show, params: { id: character.id, post_id: 0 }
      expect(response).to have_http_status(422)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("Post could not be found.")
    end

    it "requires post to have permission when provided a post_id", :show_in_doc do
      post = create(:post, privacy: :private, with_character: true)
      get :show, params: { id: post.written.character_id, post_id: post.id }
      expect(response).to have_http_status(:forbidden)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "includes alias_id_for_post field when given post_id" do
      character = create(:character)
      post = create(:post, user: character.user)
      get :show, params: { id: character.id, post_id: post.id }
      expect(response).to have_http_status(200)
      expect(response.json).to have_key('alias_id_for_post')
      expect(response.json['alias_id_for_post']).to be_nil
    end

    it "sets correct alias_id_for_post when given post_id with recently used alias in post", :show_in_doc do
      calias = create(:alias)
      character = calias.character
      post = create(:post, user: character.user, character: character, character_alias: calias)
      get :show, params: { id: character.id, post_id: post.id }
      expect(response).to have_http_status(200)
      expect(response.json).to have_key('alias_id_for_post')
      expect(response.json['alias_id_for_post']).to eq(calias.id)
    end

    it "sets correct alias_id_for_post when given post_id with recently used alias in post" do
      calias = create(:alias)
      character = calias.character
      post = create(:post, user: character.user, character: character)
      create(:reply, post: post, user: character.user, character: character, character_alias: calias) # reply
      get :show, params: { id: character.id, post_id: post.id }
      expect(response).to have_http_status(200)
      expect(response.json).to have_key('alias_id_for_post')
      expect(response.json['alias_id_for_post']).to eq(calias.id)
    end
  end

  describe "PUT update" do
    it "requires login", :show_in_doc do
      put :update, params: { id: -1 }
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "requires valid character", :show_in_doc do
      api_login
      put :update, params: { id: -1 }
      expect(response).to have_http_status(404)
      expect(response.json['errors'][0]['message']).to eq("Character could not be found.")
    end

    it "requires permission", :show_in_doc do
      character = create(:character)
      api_login
      put :update, params: { id: character.id }
      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "does not change icon if invalid icon provided" do
      icon = create(:icon)
      character = create(:character, user: icon.user, default_icon_id: icon.id)
      api_login_as(character.user)
      put :update, params: { id: character.id, character: {default_icon_id: -1} }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Default icon could not be found")
      expect(character.reload.default_icon_id).to eq(icon.id)
    end

    it "does not change icon if someone else's icon provided" do
      icon = create(:icon)
      character = create(:character, user: icon.user, default_icon_id: icon.id)
      api_login_as(character.user)
      put :update, params: { id: character.id, character: {default_icon_id: create(:icon).id} }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq("Default icon must be yours")
      expect(character.reload.default_icon_id).to eq(icon.id)
    end

    it "removes icon successfully with empty icon_id" do
      icon = create(:icon)
      character = create(:character, user: icon.user, default_icon_id: icon.id)
      api_login_as(character.user)
      put :update, params: { id: character.id, character: {default_icon_id: ''} }
      expect(response.status).to eq(200)
      expect(response.json['name']).to eq(character.name)
      expect(character.reload.default_icon_id).to be_nil
    end

    it "changes icon if valid", :show_in_doc do
      icon = create(:icon)
      character = create(:character, user: icon.user, default_icon_id: icon.id)
      new_icon = create(:icon, user: icon.user)
      api_login_as(character.user)

      put :update, params: { id: character.id, character: {default_icon_id: new_icon.id} }

      expect(response.status).to eq(200)
      expect(response.json['name']).to eq(character.name)
      expect(character.reload.default_icon_id).to eq(new_icon.id)
    end

    it "handles validation failures and invalid params", :show_in_doc do
      icon = create(:icon)
      character = create(:character, user: icon.user, default_icon_id: icon.id)
      new_icon = create(:icon, user: icon.user)
      api_login_as(character.user)

      put :update, params: { id: character.id, character: {default_icon_id: new_icon.id, name: '', user_id: nil} }

      expect(response.status).to eq(422)
      expect(response.json['errors'][0]['message']).to eq("Name can't be blank")
      expect(character.reload.default_icon_id).to eq(icon.id)
      expect(character.reload.user_id).to eq(icon.user_id)
    end
  end

  describe "POST reorder" do
    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "requires a character you have access to" do
      character = create(:character)
      char_gal1 = create(:characters_gallery, character_id: character.id)
      char_gal2 = create(:characters_gallery, character_id: character.id)
      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(1)

      section_ids = [char_gal2.id, char_gal1.id]

      api_login
      post :reorder, params: { ordered_characters_gallery_ids: section_ids }
      expect(response).to have_http_status(403)
      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(1)
    end

    it "requires a single character" do
      user = create(:user)
      character1 = create(:character, user: user)
      character2 = create(:character, user: user)
      char_gal1 = create(:characters_gallery, character_id: character1.id)
      char_gal2 = create(:characters_gallery, character_id: character2.id)
      char_gal3 = create(:characters_gallery, character_id: character2.id)

      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(0)
      expect(char_gal3.reload.section_order).to eq(1)

      section_ids = [char_gal3.id, char_gal2.id, char_gal1.id]
      api_login_as(user)
      post :reorder, params: { ordered_characters_gallery_ids: section_ids }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq('Character galleries must be from one character')
      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(0)
      expect(char_gal3.reload.section_order).to eq(1)
    end

    it "requires valid section ids" do
      character = create(:character)
      char_gal1 = create(:characters_gallery, character_id: character.id)
      char_gal2 = create(:characters_gallery, character_id: character.id)
      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(1)
      section_ids = [-1]

      api_login_as(character.user)
      post :reorder, params: { ordered_characters_gallery_ids: section_ids }
      expect(response).to have_http_status(404)
      expect(response.json['errors'][0]['message']).to eq('Some character galleries could not be found: -1')
      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(1)
    end

    it "works for valid changes", :show_in_doc do
      character = create(:character)
      character2 = create(:character, user: character.user)
      char_gal1 = create(:characters_gallery, character_id: character.id)
      char_gal2 = create(:characters_gallery, character_id: character.id)
      char_gal3 = create(:characters_gallery, character_id: character.id)
      char_gal4 = create(:characters_gallery, character_id: character.id)
      char_gal5 = create(:characters_gallery, character_id: character2.id)

      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(1)
      expect(char_gal3.reload.section_order).to eq(2)
      expect(char_gal4.reload.section_order).to eq(3)
      expect(char_gal5.reload.section_order).to eq(0)

      section_ids = [char_gal3.id, char_gal1.id, char_gal4.id, char_gal2.id]

      api_login_as(character.user)
      post :reorder, params: { ordered_characters_gallery_ids: section_ids }
      expect(response).to have_http_status(200)
      expect(response.json).to eq({'characters_gallery_ids' => section_ids})
      expect(char_gal1.reload.section_order).to eq(1)
      expect(char_gal2.reload.section_order).to eq(3)
      expect(char_gal3.reload.section_order).to eq(0)
      expect(char_gal4.reload.section_order).to eq(2)
      expect(char_gal5.reload.section_order).to eq(0)
    end

    it "works when specifying valid subset", :show_in_doc do
      character = create(:character)
      character2 = create(:character, user: character.user)
      char_gal1 = create(:characters_gallery, character_id: character.id)
      char_gal2 = create(:characters_gallery, character_id: character.id)
      char_gal3 = create(:characters_gallery, character_id: character.id)
      char_gal4 = create(:characters_gallery, character_id: character.id)
      char_gal5 = create(:characters_gallery, character_id: character2.id)

      expect(char_gal1.reload.section_order).to eq(0)
      expect(char_gal2.reload.section_order).to eq(1)
      expect(char_gal3.reload.section_order).to eq(2)
      expect(char_gal4.reload.section_order).to eq(3)
      expect(char_gal5.reload.section_order).to eq(0)

      section_ids = [char_gal3.id, char_gal1.id]

      api_login_as(character.user)
      post :reorder, params: { ordered_characters_gallery_ids: section_ids }
      expect(response).to have_http_status(200)
      expect(response.json).to eq({'characters_gallery_ids' => [char_gal3.id, char_gal1.id, char_gal2.id, char_gal4.id]})
      expect(char_gal1.reload.section_order).to eq(1)
      expect(char_gal2.reload.section_order).to eq(2)
      expect(char_gal3.reload.section_order).to eq(0)
      expect(char_gal4.reload.section_order).to eq(3)
      expect(char_gal5.reload.section_order).to eq(0)
    end
  end
end
