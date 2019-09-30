require "spec_helper"

RSpec.describe IconsController do
  include ActiveJob::TestHelper

  describe "DELETE delete_multiple" do
    it "requires login" do
      delete :delete_multiple
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires icons" do
      user_id = login
      delete :delete_multiple
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("No icons selected.")
    end

    it "requires valid icons" do
      icon = create(:icon)
      icon.destroy!
      user_id = login
      delete :delete_multiple, params: { marked_ids: [0, '0', 'abc', -1, '-1', icon.id] }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("No icons selected.")
    end

    context "removing icons from a gallery" do
      let(:user) { create(:user) }
      before(:each) { login_as(user) }

      it "requires gallery" do
        icon = create(:icon, user: user)
        delete :delete_multiple, params: { marked_ids: [icon.id], gallery_delete: true }
        expect(response).to redirect_to(user_galleries_url(user.id))
        expect(flash[:error]).to eq("Gallery could not be found.")
      end

      it "requires your gallery" do
        icon = create(:icon, user: user)
        gallery = create(:gallery)
        delete :delete_multiple, params: { marked_ids: [icon.id], gallery_id: gallery.id, gallery_delete: true }
        expect(response).to redirect_to(user_galleries_url(user.id))
        expect(flash[:error]).to eq("That is not your gallery.")
      end

      it "skips other people's icons" do
        icon = create(:icon)
        gallery = create(:gallery, user: user)
        gallery.icons << icon
        icon.reload
        expect(icon.galleries.count).to eq(1)
        delete :delete_multiple, params: { marked_ids: [icon.id], gallery_id: gallery.id, gallery_delete: true }
        icon.reload
        expect(icon.galleries.count).to eq(1)
      end

      it "removes int ids from gallery" do
        icon = create(:icon, user: user)
        gallery = create(:gallery, user: user)
        gallery.icons << icon
        expect(icon.galleries.count).to eq(1)
        delete :delete_multiple, params: { marked_ids: [icon.id], gallery_id: gallery.id, gallery_delete: true }
        expect(icon.galleries.count).to eq(0)
        expect(response).to redirect_to(gallery_url(gallery))
        expect(flash[:success]).to eq("Icons removed from gallery.")
      end

      it "removes string ids from gallery" do
        icon = create(:icon, user: user)
        gallery = create(:gallery, user: user)
        gallery.icons << icon
        expect(icon.galleries.count).to eq(1)
        delete :delete_multiple, params: { marked_ids: [icon.id.to_s], gallery_id: gallery.id, gallery_delete: true }
        expect(icon.galleries.count).to eq(0)
        expect(response).to redirect_to(gallery_url(gallery))
        expect(flash[:success]).to eq("Icons removed from gallery.")
      end

      it "goes back to index page if given" do
        icon = create(:icon, user: user)
        gallery = create(:gallery, user: user)
        gallery.icons << icon
        expect(icon.galleries.count).to eq(1)
        delete :delete_multiple, params: { marked_ids: [icon.id.to_s], gallery_id: gallery.id, gallery_delete: true, return_to: 'index' }
        expect(icon.galleries.count).to eq(0)
        expect(response).to redirect_to(user_galleries_url(user.id, anchor: "gallery-#{gallery.id}"))
      end

      it "goes back to index page if given" do
        icon = create(:icon, user: user)
        gallery = create(:gallery, user: user)
        group = create(:gallery_group, user: user)
        group.galleries << gallery
        gallery.icons << icon
        expect(icon.galleries.count).to eq(1)
        delete :delete_multiple, params: { marked_ids: [icon.id.to_s], gallery_id: gallery.id, gallery_delete: true, return_tag: group.id }
        expect(icon.galleries.count).to eq(0)
        expect(response).to redirect_to(tag_url(group, anchor: "gallery-#{gallery.id}"))
      end
    end

    context "deleting icons from the site" do
      let(:user) { create(:user) }
      before(:each) { login_as(user) }

      it "skips other people's icons" do
        icon = create(:icon)
        delete :delete_multiple, params: { marked_ids: [icon.id] }
        icon.reload
      end

      it "removes int ids from gallery" do
        icon = create(:icon, user: user)
        delete :delete_multiple, params: { marked_ids: [icon.id] }
        expect(Icon.find_by_id(icon.id)).to be_nil
      end

      it "removes string ids from gallery" do
        icon = create(:icon, user: user)
        icon2 = create(:icon, user: user)
        delete :delete_multiple, params: { marked_ids: [icon.id.to_s, icon2.id.to_s] }
        expect(Icon.find_by_id(icon.id)).to be_nil
        expect(Icon.find_by_id(icon2.id)).to be_nil
        expect(response).to redirect_to(user_gallery_path(id: 0, user_id: user.id))
      end

      it "goes back to index page if given" do
        icon = create(:icon, user: user)
        gallery = create(:gallery, user: user)
        gallery.icons << icon
        delete :delete_multiple, params: { marked_ids: [icon.id], gallery_id: gallery.id, return_to: 'index' }
        expect(Icon.find_by_id(icon.id)).to be_nil
        expect(response).to redirect_to(user_galleries_url(user.id, anchor: "gallery-#{gallery.id}"))
      end

      it "goes back to index page if given" do
        icon = create(:icon, user: user)
        gallery = create(:gallery, user: user)
        group = create(:gallery_group, user: user)
        group.galleries << gallery
        gallery.icons << icon
        delete :delete_multiple, params: { marked_ids: [icon.id], gallery_id: gallery.id, return_tag: group.id }
        expect(Icon.find_by_id(icon.id)).to be_nil
        expect(response).to redirect_to(tag_url(group, anchor: "gallery-#{gallery.id}"))
      end
    end
  end

  describe "GET show" do
    it "requires valid icon logged out" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires valid icon logged in" do
      user_id = login
      get :show, params: { id: -1 }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "successfully loads when logged out" do
      icon = create(:icon)
      get :show, params: { id: icon.id }
      expect(response).to have_http_status(200)
      expect(assigns(:posts)).to be_nil
    end

    it "successfully loads when logged in" do
      login
      icon = create(:icon)
      get :show, params: { id: icon.id }
      expect(response).to have_http_status(200)
      expect(assigns(:posts)).to be_nil
    end

    it "calculates OpenGraph meta" do
      user = create(:user, username: 'user')
      gallery1 = create(:gallery, name: 'gallery 1', user: user)
      gallery2 = create(:gallery, name: 'gallery 2', user: user)
      icon = create(:icon, keyword: 'icon', credit: "sample credit", gallery_ids: [gallery1.id, gallery2.id], user: user)

      get :show, params: { id: icon.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description, :image])
      expect(meta_og[:url]).to eq(icon_url(icon))
      expect(meta_og[:title]).to eq('icon')
      expect(meta_og[:description]).to eq('Galleries: gallery 1, gallery 2. By sample credit')
      expect(meta_og[:image].keys).to match_array([:src, :width, :height])
      expect(meta_og[:image][:src]).to eq(icon.url)
      expect(meta_og[:image][:width]).to eq('75')
      expect(meta_og[:image][:width]).to eq('75')
    end

    context "post view" do
      let(:icon) { create(:icon) }
      let(:post) { create(:post, icon: icon, user: icon.user) }
      let(:other_post) { create(:post) }
      let(:reply) { create(:reply, icon: icon, user: icon.user, post: other_post) }

      before(:each) do
        create(:post) # should not be found
        post
        reply
      end

      it "loads posts logged out" do
        get :show, params: { id: icon.id, view: 'posts' }
        expect(response).to have_http_status(200)
        expect(assigns(:posts)).to match_array([post, other_post])
      end

      it "loads posts logged in" do
        login
        get :show, params: { id: icon.id, view: 'posts' }
        expect(response).to have_http_status(200)
        expect(assigns(:posts)).to match_array([post, other_post])
      end

      it "orders posts correctly" do
        post3 = create(:post, icon: icon, user: icon.user)
        post4 = create(:post, icon: icon, user: icon.user)
        post.update!(tagged_at: Time.zone.now - 5.minutes)
        other_post.update!(tagged_at: Time.zone.now - 2.minutes)
        post3.update!(tagged_at: Time.zone.now - 8.minutes)
        post4.update!(tagged_at: Time.zone.now - 4.minutes)
        get :show, params: { id: icon.id, view: 'posts' }
        expect(assigns(:posts)).to eq([other_post, post4, post, post3])
      end
    end

    context "galleries view" do
      render_views
      let(:gallery) { create(:gallery) }
      let(:icon) { create(:icon, galleries: [gallery], user: gallery.user) }
      before(:each) do
        icon
      end

      it "loads logged out" do
        get :show, params: { id: icon.id, view: 'galleries' }
        expect(response).to have_http_status(200)
        expect(assigns(:javascripts)).to include('galleries/expander_old')
      end

      it "loads logged in" do
        login
        get :show, params: { id: icon.id, view: 'galleries' }
        expect(response).to have_http_status(200)
        expect(assigns(:javascripts)).to include('galleries/expander_old')
      end
    end

    context "stats view" do
      let(:icon) { create(:icon) }
      let(:post) { create(:post, icon: icon, user: icon.user) }
      let(:reply) { create(:reply, icon: icon, user: icon.user, post: create(:post)) }
      let(:private_post) { create(:post, icon: icon, user: icon.user, privacy: Concealable::PRIVATE) }
      let(:registered_post) { create(:post, icon: icon, user: icon.user, privacy: Concealable::REGISTERED) }
      before(:each) do
        create(:reply, post: post, user: icon.user, icon: icon)
        reply
        private_post
        registered_post
      end

      it "fetches correct counts for icon owner" do
        login_as(icon.user)
        get :show, params: { id: icon.id }
        expect(response).to have_http_status(200)
        expect(assigns(:times_used)).to eq(5)
        expect(assigns(:posts_used)).to eq(4)
      end

      it "fetches correct counts when logged out" do
        login
        get :show, params: { id: icon.id }
        expect(response).to have_http_status(200)
        expect(assigns(:times_used)).to eq(4)
        expect(assigns(:posts_used)).to eq(3)
      end

      it "fetches corect counts when logged in" do
        get :show, params: { id: icon.id }
        expect(response).to have_http_status(200)
        expect(assigns(:times_used)).to eq(3)
        expect(assigns(:posts_used)).to eq(2)
      end
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response.status).to eq(302)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid icon" do
      user_id = login
      get :edit, params: { id: -1 }
      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires your icon" do
      user_id = login
      get :edit, params: { id: create(:icon).id }
      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq(user_galleries_url(user_id))
      expect(flash[:error]).to eq("That is not your icon.")
    end

    it "successfully loads" do
      user_id = login
      icon = create(:icon, user_id: user_id)
      get :edit, params: { id: icon.id }
      expect(response.status).to eq(200)
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid icon" do
      user_id = login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires your icon" do
      user_id = login
      put :update, params: { id: create(:icon).id }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("That is not your icon.")
    end

    it "requires valid params" do
      icon = create(:icon)
      login_as(icon.user)
      put :update, params: { id: icon.id, icon: {url: ''} }
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Your icon could not be saved due to the following problems:")
    end

    it "successfully updates" do
      icon = create(:icon)
      login_as(icon.user)
      new_url = icon.url + '?param'
      put :update, params: { id: icon.id, icon: {url: new_url, keyword: 'new keyword', credit: 'new credit'} }
      expect(response).to redirect_to(icon_url(icon))
      expect(flash[:success]).to eq("Icon updated.")
      icon.reload
      expect(icon.url).to eq(new_url)
      expect(icon.keyword).to eq('new keyword')
      expect(icon.credit).to eq('new credit')
    end

    it "successfully uploads an icon" do
      user = create(:user)
      login_as(user)
      icon = create(:icon, user: user)
      file = fixture_file_upload('app/assets/images/icons/note_go_strong.png', 'image/png')
      expect { put :update, params: { id: icon.id, icon: { image: file } } }.to change(ActiveStorage::Attachment, :count).by(1)
      expect(flash[:success]).to be_present
      icon.reload
      expect(icon.image.blob.filename).to eq('note_go_strong.png')
      expect(icon.url).to include('note_go_strong.png')
      expect(icon.image).to be_attached
    end

    it "successfully changes an uploaded icon" do
      user = create(:user)
      login_as(user)
      icon = create(:uploaded_icon, user: user)
      expect(icon.image).to be_attached
      new_image = fixture_file_upload('app/assets/images/icons/accept.png', 'image/png')
      expect { put :update, params: { id: icon.id, icon: { image: new_image } } }.to change(ActiveStorage::Blob, :count).by(1)
      expect(flash[:success]).to be_present
      icon.reload
      expect(icon.image).to be_attached
      expect(icon.image.blob.filename).to eq('accept.png')
      expect(icon.url).to include('accept.png')
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response.status).to eq(302)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid icon" do
      user_id = login
      delete :destroy, params: { id: -1 }
      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires your icon" do
      user_id = login
      delete :destroy, params: { id: create(:icon).id }
      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq(user_galleries_url(user_id))
      expect(flash[:error]).to eq("That is not your icon.")
    end

    it "successfully destroys" do
      user_id = login
      icon = create(:icon, user_id: user_id)
      delete :destroy, params: { id: icon.id }
      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq(user_galleries_url(user_id))
      expect(flash[:success]).to eq("Icon deleted successfully.")
      expect(Icon.find_by_id(icon.id)).to be_nil
    end

    it "successfully goes to gallery if one" do
      icon = create(:icon)
      gallery = create(:gallery, user: icon.user)
      icon.galleries << gallery
      login_as(icon.user)
      delete :destroy, params: { id: icon.id }
      expect(response.status).to eq(302)
      expect(response.redirect_url).to eq(gallery_url(gallery))
      expect(flash[:success]).to eq("Icon deleted successfully.")
      expect(Icon.find_by_id(icon.id)).to be_nil
    end

    it "handles destroy failure" do
      icon = create(:icon)
      post = create(:post, user: icon.user, icon: icon)
      login_as(icon.user)
      expect_any_instance_of(Icon).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: icon.id }
      expect(response).to redirect_to(icon_url(icon))
      expect(flash[:error]).to eq({message: "Icon could not be deleted.", array: []})
      expect(post.reload.icon).to eq(icon)
    end
  end

  describe "POST avatar" do
    it "requires login" do
      post :avatar, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid icon" do
      user_id = login
      post :avatar, params: { id: -1 }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires your icon" do
      user_id = login
      post :avatar, params: { id: create(:icon).id }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("That is not your icon.")
    end

    it "handles save errors" do
      user = create(:user)
      icon = create(:icon, user: user)
      expect(user.avatar_id).to be_nil
      login_as(user)

      expect_any_instance_of(User).to receive(:update).and_return(false)
      post :avatar, params: { id: icon.id }

      expect(response).to redirect_to(icon_url(icon))
      expect(flash[:error]).to eq("Something went wrong.")
      expect(user.reload.avatar_id).to be_nil
    end

    it "works" do
      user = create(:user)
      icon = create(:icon, user: user)
      expect(user.avatar_id).to be_nil
      login_as(user)

      post :avatar, params: { id: icon.id }

      expect(response).to redirect_to(icon_url(icon))
      expect(flash[:success]).to eq("Avatar has been set!")
      expect(user.reload.avatar_id).to eq(icon.id)
    end
  end

  describe "GET replace" do
    it "requires login" do
      get :replace, params: { id: create(:icon).id }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid icon" do
      user_id = login
      get :replace, params: { id: -1 }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires your icon" do
      user_id = login
      get :replace, params: { id: create(:icon).id }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("That is not your icon.")
    end

    context "with galleryless icon" do
      it "sets variables correctly" do
        user = create(:user)
        icon = create(:icon, user_id: user.id)
        alts = Array.new(5) { create(:icon, user_id: user.id) }
        post = create(:post, user_id: user.id, icon_id: icon.id)
        create(:reply, post_id: post.id, user_id: user.id, icon_id: icon.id) # post reply
        reply = create(:reply, user_id: user.id, icon_id: icon.id)

        other_icon = create(:icon, user_id: user.id)
        gallery = create(:gallery, user_id: user.id, icon_ids: [other_icon.id])
        expect(gallery.icons).to match_array([other_icon])
        create(:post, user_id: user.id, icon_id: other_icon.id) # other post
        create(:reply, user_id: user.id, icon_id: other_icon.id) # other reply

        login_as(icon.user)
        get :replace, params: { id: icon.id }
        expect(response).to have_http_status(200)
        expect(assigns(:alts)).to match_array(alts)
        expect(assigns(:posts)).to match_array([post, reply.post])
        expect(assigns(:page_title)).to eq("Replace Icon: " + icon.keyword)
      end
    end

    context "with icon gallery" do
      it "sets variables correctly" do
        user = create(:user)
        icon = create(:icon, user_id: user.id)
        alts = Array.new(5) { create(:icon, user: user) }
        gallery = create(:gallery, user: user, icon_ids: [icon.id] + alts.map(&:id))
        other_icon = create(:icon, user: user)

        expect(gallery.icons).to match_array([icon] + alts)

        post = create(:post, user: user, icon: icon)
        create(:reply, post: post, user: user, icon: icon) # post reply
        reply = create(:reply, user: user, icon: icon)

        create(:post, user: user, icon: other_icon) # other post
        create(:reply, user: user, icon: other_icon) # other reply

        login_as(icon.user)
        get :replace, params: { id: icon.id }
        expect(response).to have_http_status(200)
        expect(assigns(:alts)).to match_array(alts)
        expect(assigns(:posts)).to match_array([post, reply.post])
        expect(assigns(:page_title)).to eq("Replace Icon: " + icon.keyword)
      end
    end
  end

  describe "POST do_replace" do
    it "requires login" do
      post :do_replace, params: { id: create(:icon).id }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid icon" do
      user_id = login
      post :do_replace, params: { id: -1 }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("Icon could not be found.")
    end

    it "requires your icon" do
      user_id = login
      post :do_replace, params: { id: create(:icon).id }
      expect(response).to redirect_to(user_galleries_url(user_id))
      expect(flash[:error]).to eq("That is not your icon.")
    end

    it "requires valid other icon" do
      icon = create(:icon)
      login_as(icon.user)
      post :do_replace, params: { id: icon.id, icon_dropdown: -1 }
      expect(response).to redirect_to(replace_icon_path(icon))
      expect(flash[:error]).to eq('Icon could not be found.')
    end

    it "requires other icon to be yours if present" do
      icon = create(:icon)
      other_icon = create(:icon)
      login_as(icon.user)
      post :do_replace, params: { id: icon.id, icon_dropdown: other_icon.id }
      expect(response).to redirect_to(replace_icon_path(icon))
      expect(flash[:error]).to eq('That is not your icon.')
    end

    it "succeeds with valid other icon" do
      user = create(:user)
      icon = create(:icon, user: user)
      other_icon = create(:icon, user: user)
      icon_post = create(:post, user: user, icon: icon)
      reply = create(:reply, user: user, icon: icon)
      reply_post_icon = reply.post.icon_id

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: icon.id, icon_dropdown: other_icon.id }
      end
      expect(response).to redirect_to(icon_path(icon))
      expect(flash[:success]).to eq('All uses of this icon will be replaced.')

      expect(icon_post.reload.icon_id).to eq(other_icon.id)
      expect(reply.reload.icon_id).to eq(other_icon.id)
      expect(reply.post.reload.icon_id).to eq(reply_post_icon) # check it doesn't replace all replies in a post
    end

    it "succeeds with no other icon" do
      user = create(:user)
      icon = create(:icon, user: user)
      icon_post = create(:post, user: user, icon: icon)
      reply = create(:reply, user: user, icon: icon)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: icon.id }
      end
      expect(response).to redirect_to(icon_path(icon))
      expect(flash[:success]).to eq('All uses of this icon will be replaced.')

      expect(icon_post.reload.icon_id).to be_nil
      expect(reply.reload.icon_id).to be_nil
    end

    it "filters to selected posts if given" do
      user = create(:user)
      icon = create(:icon, user: user)
      other_icon = create(:icon, user: user)
      icon_post = create(:post, user: user, icon: icon)
      icon_reply = create(:reply, user: user, icon: icon)
      other_post = create(:post, user: user, icon: icon)

      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        post :do_replace, params: { id: icon.id, icon_dropdown: other_icon.id, post_ids: [icon_post.id, icon_reply.post.id] }
      end
      expect(response).to redirect_to(icon_path(icon))
      expect(flash[:success]).to eq('All uses of this icon will be replaced.')

      expect(icon_post.reload.icon_id).to eq(other_icon.id)
      expect(icon_reply.reload.icon_id).to eq(other_icon.id)
      expect(other_post.reload.icon_id).to eq(icon.id)
    end
  end
end
