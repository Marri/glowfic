RSpec.describe TagsController do
  describe "GET index" do
    context "with views" do
      render_views
      def create_tags
        # set up sample tags, empty and not
        empty_tag = create(:label, name: 'Empty')
        tag = create(:label)
        create(:post, labels: [tag])
        setting = create(:setting, name: 'Empty')
        owned_setting = create(:setting, owned: true)

        empty_group = create(:gallery_group)
        group1 = create(:gallery_group)
        create(:gallery, gallery_groups: [group1])
        [empty_tag, tag, empty_group, group1, setting, owned_setting]
      end

      it "succeeds when logged out" do
        tags = create_tags
        get :index
        expect(response.status).to eq(200)
        tags.reject! { |tag| tag.is_a?(GalleryGroup) }
        expect(assigns(:tags)).to match_array(tags)
      end

      it "succeeds with type filter" do
        tags = create_tags
        get :index, params: { view: 'Setting' }
        expect(response).to have_http_status(200)
        expect(assigns(:tags)).to match_array(tags[-2..-1])
        expect(assigns(:page_title)).to eq('Settings')
      end

      it "succeeds with name filter" do
        tags = create_tags
        get :index, params: {name: 'Empty'}
        expect(response).to have_http_status(200)
        expect(assigns(:tags)).to match_array([tags[0], tags[4]])
        expect(assigns(:page_title)).to eq('Tags')
      end

      it "succeeds when logged in" do
        tags = create_tags
        login_as(tags.first.user)
        get :index
        expect(response.status).to eq(200)
        tags.reject! { |tag| tag.is_a?(GalleryGroup) }
        expect(assigns(:tags)).to match_array(tags)
      end
    end

    it "orders tags by type and then name" do
      tag2 = create(:label, name: "b")
      tag1 = create(:label, name: "a")
      setting1 = create(:setting, name: "a")
      setting2 = create(:setting, owned: true, name: "b")
      warning2 = create(:content_warning, name: "b")
      warning1 = create(:content_warning, name: "a")
      get :index
      expect(assigns(:tags)).to eq([setting1, setting2, tag1, tag2, warning1, warning2])
    end

    it "performs a full-text match on tag names" do
      warning2 = create(:content_warning, name: 'dubcon')
      warning1 = create(:content_warning, name: 'con')
      get :index, params: { name: 'con' }
      expect(assigns(:tags)).to eq([warning1, warning2])
    end

    it 'checks for valid tag type' do
      get :index, params: { view: 'NotATagType' }
      expect(response).to redirect_to(tags_path)
      expect(flash[:error]).to eq("Invalid filter")
    end
  end

  describe "GET show" do
    it "requires valid tag" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(tags_url)
      expect(flash[:error]).to eq("Tag could not be found.")
    end

    it "calculates OpenGraph meta for labels" do
      label = create(:label, name: 'label')
      create_list(:post, 2, labels: [label])

      get :show, params: { id: label.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(tag_url(label))
      expect(meta_og[:title]).to eq('label · Label')
      expect(meta_og[:description]).to eq('2 posts')
    end

    it "calculates OpenGraph meta for unowned settings" do
      setting = create(:setting,
        name: 'setting',
        description: 'this is an example setting',
      )
      create_list(:post, 2, settings: [setting])
      create_list(:character, 3, settings: [setting])

      get :show, params: { id: setting.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(tag_url(setting))
      expect(meta_og[:title]).to eq('setting · Setting')
      expect(meta_og[:description]).to eq("this is an example setting\n2 posts, 3 characters")
    end

    it "calculates OpenGraph meta for owned settings" do
      setting = create(:setting,
        name: 'setting',
        user: create(:user, username: "User"),
        description: 'this is an example setting',
        owned: true,
      )
      create_list(:post, 2, settings: [setting])
      create_list(:character, 3, settings: [setting])

      get :show, params: { id: setting.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(tag_url(setting))
      expect(meta_og[:title]).to eq('setting · User · Setting')
      expect(meta_og[:description]).to eq("this is an example setting\n2 posts, 3 characters")
    end

    it "calculates OpenGraph meta for gallery groups" do
      group = create(:gallery_group, name: 'group')
      create_list(:gallery, 2, gallery_groups: [group])
      create_list(:character, 3, gallery_groups: [group])

      get :show, params: { id: group.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(tag_url(group))
      expect(meta_og[:title]).to eq('group · Gallery Group')
      expect(meta_og[:description]).to eq('2 galleries, 3 characters')
    end

    context "with views" do
      render_views
      it "succeeds with valid post tag" do
        tag = create(:label)
        post = create(:post, labels: [tag])
        get :show, params: { id: tag.id, view: 'posts' }
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "succeeds for logged in users with valid post tag" do
        tag = create(:setting)
        post = create(:post, settings: [tag])
        login
        get :show, params: { id: tag.id, view: 'posts' }
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it 'succeeds for canons with settings' do
        tag = create(:setting)
        tag.child_settings << create(:setting)
        get :show, params: { id: tag.id, view: 'settings' }
        expect(response).to have_http_status(200)
      end

      it "succeeds with valid gallery tag" do
        group = create(:gallery_group)
        gallery = create(:gallery, gallery_groups: [group])
        get :show, params: { id: group.id, view: 'galleries' }
        expect(response.status).to eq(200)
        expect(assigns(:galleries)).to match_array([gallery])
      end

      it "succeeds for logged in users with valid gallery tag" do
        group = create(:gallery_group)
        gallery = create(:gallery, gallery_groups: [group])
        login
        get :show, params: { id: group.id, view: 'galleries' }
        expect(response.status).to eq(200)
        expect(assigns(:galleries)).to match_array([gallery])
      end

      context "gallery group" do
        it "succeeds with valid character tag" do
          group = create(:gallery_group)
          character = create(:character, gallery_groups: [group])
          get :show, params: { id: group.id, view: 'characters' }
          expect(response.status).to eq(200)
          expect(assigns(:characters)).to match_array([character])
        end

        it "succeeds for logged in users with valid character tag" do
          group = create(:gallery_group)
          character = create(:character, gallery_groups: [group])
          login
          get :show, params: { id: group.id, view: 'characters' }
          expect(response.status).to eq(200)
          expect(assigns(:characters)).to match_array([character])
        end

        it "orders galleries correctly" do
          group = create(:gallery_group)
          gallery2 = create(:gallery, gallery_groups: [group], name: "b")
          gallery3 = create(:gallery, gallery_groups: [group], name: "c")
          gallery1 = create(:gallery, gallery_groups: [group], name: "a")
          get :show, params: { id: group.id, view: 'galleries' }
          expect(response.status).to eq(200)
          expect(assigns(:galleries)).to match_array([gallery1, gallery2, gallery3])
        end
      end

      context "setting" do
        it "succeeds with valid character tag" do
          setting = create(:setting)
          character = create(:character, settings: [setting])
          get :show, params: { id: setting.id, view: 'characters' }
          expect(response.status).to eq(200)
          expect(assigns(:characters)).to match_array([character])
        end

        it "succeeds for logged in users with valid character tag" do
          setting = create(:setting)
          character = create(:character, settings: [setting])
          login
          get :show, params: { id: setting.id, view: 'characters' }
          expect(response.status).to eq(200)
          expect(assigns(:characters)).to match_array([character])
        end

        it "succeeds for owned settings" do
          setting = create(:setting, owned: true)
          get :show, params: { id: setting.id }
          expect(response.status).to eq(200)
        end

        it "succeeds for settings without characters" do
          setting = create(:setting)
          get :show, params: { id: setting.id, view: 'characters' }
          expect(response.status).to eq(200)
          expect(assigns(:characters)).to be_empty
        end
      end
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid tag" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(tags_url)
      expect(flash[:error]).to eq("Tag could not be found.")
    end

    it "requires permission" do
      tag = create(:label, owned: true)
      login
      get :edit, params: { id: tag.id }
      expect(response).to redirect_to(tag_url(tag))
      expect(flash[:error]).to eq("You do not have permission to modify this tag.")
    end

    it "allows admin to edit the tag" do
      tag = create(:label)
      login_as(create(:admin_user))
      get :edit, params: { id: tag.id }
      expect(response.status).to eq(200)
    end

    it "allows mod to edit the tag" do
      stub_const("Permissible::MOD_PERMS", [:edit_tags])
      tag = create(:label)
      login_as(create(:mod_user))
      get :edit, params: { id: tag.id }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid tag" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(tags_url)
      expect(flash[:error]).to eq("Tag could not be found.")
    end

    it "requires permission" do
      login
      tag = create(:label, owned: true)
      put :update, params: { id: tag.id }
      expect(response).to redirect_to(tag_url(tag))
      expect(flash[:error]).to eq("You do not have permission to modify this tag.")
    end

    it "requires valid params" do
      tag = create(:setting)
      login_as(create(:admin_user))
      put :update, params: { id: tag.id, tag: {name: nil} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Setting could not be updated because of the following problems:")
    end

    it "allows admin to update the tag" do
      tag = create(:label)
      name = tag.name + 'Edited'
      login_as(create(:admin_user))
      put :update, params: { id: tag.id, tag: {name: name} }
      expect(response).to redirect_to(tag_url(tag))
      expect(flash[:success]).to eq("Tag updated.")
      expect(tag.reload.name).to eq(name)
    end

    it "allows update of setting tags" do
      tag = create(:setting)
      parent_tag = create(:setting)
      login_as(tag.user)
      expect(tag.parent_settings).to be_empty
      put :update, params: { id: tag.id, tag: {name: 'newname', parent_setting_ids: ["", parent_tag.id.to_s]} }
      expect(tag.reload.name).to eq('newname')
      expect(Setting.find(tag.id).parent_settings).to eq([parent_tag])
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid tag" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(tags_url)
      expect(flash[:error]).to eq("Tag could not be found.")
    end

    it "requires permission" do
      tag = create(:label, owned: true)
      login
      delete :destroy, params: { id: tag.id }
      expect(response).to redirect_to(tag_url(tag))
      expect(flash[:error]).to eq("You do not have permission to modify this tag.")
    end

    it "allows admin to destroy the tag" do
      tag = create(:label)
      login_as(create(:admin_user))
      delete :destroy, params: { id: tag.id }
      expect(response).to redirect_to(tags_path)
      expect(flash[:success]).to eq("Tag deleted.")
    end

    it "handles destroy failure" do
      tag = create(:label)
      login_as(tag.user)
      expect_any_instance_of(Tag).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: tag.id }
      expect(response).to redirect_to(tag_url(tag))
      expect(flash[:error]).to eq("Label could not be deleted.")
      expect(Tag.find_by(id: tag.id)).not_to be_nil
    end
  end
end
