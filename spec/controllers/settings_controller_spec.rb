RSpec.describe SettingsController do
  describe "GET index" do
    context "with views" do
      render_views
      def create_settings
        # set up sample settings, empty and not
        setting = create(:setting, name: 'Empty')
        owned_setting = create(:setting, owned: true)
        [setting, owned_setting]
      end

      it "succeeds when logged out" do
        settings = create_settings
        get :index
        expect(response.status).to eq(200)
        expect(assigns(:settings)).to match_array(settings)
      end

      it "succeeds with name filter" do
        settings = create_settings
        get :index, params: {name: 'Empty'}
        expect(response).to have_http_status(200)
        expect(assigns(:settings)).to match_array([settings[0]])
        expect(assigns(:page_title)).to eq('Settings')
      end

      it "succeeds when logged in" do
        settings = create_settings
        login_as(settings.first.user)
        get :index
        expect(response.status).to eq(200)
        expect(assigns(:settings)).to match_array(settings)
      end
    end

    it "orders settings by name" do
      setting2 = create(:setting, owned: true, name: "b")
      setting1 = create(:setting, name: "a")
      get :index
      expect(assigns(:settings)).to eq([setting1, setting2])
    end

    it "performs a full-text match on setting names" do
      setting1 = create(:setting, name: 'test')
      setting2 = create(:setting, name: 'ztest')
      get :index, params: { name: 'test' }
      expect(assigns(:settings)).to eq([setting1, setting2])
    end
  end

  describe "GET show" do
    it "requires valid setting" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(settings_url)
      expect(flash[:error]).to eq("Setting could not be found.")
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
      expect(meta_og[:url]).to eq(setting_url(setting))
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
      expect(meta_og[:url]).to eq(setting_url(setting))
      expect(meta_og[:title]).to eq('setting · User · Setting')
      expect(meta_og[:description]).to eq("this is an example setting\n2 posts, 3 characters")
    end

    context "with views" do
      render_views
      it "succeeds with valid post setting" do
        setting = create(:setting)
        post = create(:post, settings: [setting])
        get :show, params: { id: setting.id, view: 'posts' }
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it "succeeds for logged in users with valid post setting" do
        setting = create(:setting)
        post = create(:post, settings: [setting])
        login
        get :show, params: { id: setting.id, view: 'posts' }
        expect(response.status).to eq(200)
        expect(assigns(:posts)).to match_array([post])
      end

      it 'succeeds with child settings' do
        setting = create(:setting)
        setting.child_settings << create(:setting)
        get :show, params: { id: setting.id, view: 'settings' }
        expect(response).to have_http_status(200)
      end

      context "setting" do
        it "succeeds with valid character setting" do
          setting = create(:setting)
          character = create(:character, settings: [setting])
          get :show, params: { id: setting.id, view: 'characters' }
          expect(response.status).to eq(200)
          expect(assigns(:characters)).to match_array([character])
        end

        it "succeeds for logged in users with valid character setting" do
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

    it "requires valid setting" do
      login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(settings_url)
      expect(flash[:error]).to eq("Setting could not be found.")
    end

    it "requires permission" do
      setting = create(:setting, owned: true)
      login
      get :edit, params: { id: setting.id }
      expect(response).to redirect_to(setting_url(setting))
      expect(flash[:error]).to eq("You do not have permission to edit this setting.")
    end

    it "allows admin to edit the setting" do
      setting = create(:setting)
      login_as(create(:admin_user))
      get :edit, params: { id: setting.id }
      expect(response.status).to eq(200)
    end

    it "allows mod to edit the setting" do
      stub_const("Permissible::MOD_PERMS", [:edit_tags])
      setting = create(:setting)
      login_as(create(:mod_user))
      get :edit, params: { id: setting.id }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid setting" do
      login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(settings_url)
      expect(flash[:error]).to eq("Setting could not be found.")
    end

    it "requires permission" do
      login
      setting = create(:setting, owned: true)
      put :update, params: { id: setting.id }
      expect(response).to redirect_to(setting_url(setting))
      expect(flash[:error]).to eq("You do not have permission to edit this setting.")
    end

    it "requires valid params" do
      setting = create(:setting)
      login_as(create(:admin_user))
      put :update, params: { id: setting.id, setting: {name: nil} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Setting could not be saved because of the following problems:")
    end

    it "allows admin to update the setting" do
      setting = create(:setting)
      name = setting.name + 'Edited'
      login_as(create(:admin_user))
      put :update, params: { id: setting.id, setting: {name: name} }
      expect(response).to redirect_to(setting_url(setting))
      expect(flash[:success]).to eq("Setting saved!")
      expect(setting.reload.name).to eq(name)
    end

    it "allows update of setting tags" do
      setting = create(:setting)
      parent_setting = create(:setting)
      login_as(setting.user)
      expect(setting.parent_settings).to be_empty
      put :update, params: { id: setting.id, setting: {name: 'newname', parent_setting_ids: ["", parent_setting.id.to_s]} }
      expect(setting.reload.name).to eq('newname')
      expect(setting.reload.parent_settings).to eq([parent_setting])
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid setting" do
      login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(settings_url)
      expect(flash[:error]).to eq("Setting could not be found.")
    end

    it "requires permission" do
      setting = create(:setting, owned: true)
      login
      delete :destroy, params: { id: setting.id }
      expect(response).to redirect_to(setting_url(setting))
      expect(flash[:error]).to eq("You do not have permission to edit this setting.")
    end

    it "allows admin to destroy the setting" do
      setting = create(:setting, owned: true)
      login_as(create(:admin_user))
      delete :destroy, params: { id: setting.id }
      expect(response).to redirect_to(settings_path)
      expect(flash[:success]).to eq("Setting deleted.")
    end

    it "handles destroy failure" do
      setting = create(:setting)
      login_as(setting.user)
      expect_any_instance_of(Setting).to receive(:destroy).and_return(false)
      delete :destroy, params: { id: setting.id }
      expect(response).to redirect_to(setting_url(setting))
      expect(flash[:error]).to eq({message: "Setting could not be deleted.", array: []})
      expect(Setting.find_by(id: setting.id)).not_to be_nil
    end
  end
end
