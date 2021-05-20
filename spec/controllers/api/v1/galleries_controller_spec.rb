RSpec.describe Api::V1::GalleriesController do
  describe "GET show" do
    context "with zero gallery id" do
      it "requires valid user", :show_in_doc do
        get :show, params: { id: '0' }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq("Gallery user could not be found.")
      end

      it "returns galleryless icons for logged in user" do
        api_login
        get :show, params: { id: '0' }
        expect(response).to have_http_status(200)
        expect(response.json['name']).to eq('Galleryless')
        expect(response.json['icons']).to be_empty
      end

      it "returns galleryless icons for specified user", :show_in_doc do
        get :show, params: { id: '0', user_id: create(:user).id }
        expect(response).to have_http_status(200)
        expect(response.json['name']).to eq('Galleryless')
        expect(response.json['icons']).to be_empty
      end
    end

    context "with normal gallery id" do
      it "requires valid gallery id", :show_in_doc do
        expect(Gallery.find_by_id(1)).to be_nil
        get :show, params: { id: 1 }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq("Gallery could not be found.")
      end

      it "displays the gallery", :show_in_doc do
        gallery = create(:gallery, icon_count: 1)
        api_login_as(gallery.user)
        get :show, params: { id: gallery.id }
        expect(response).to have_http_status(200)
        expect(response.json['name']).to eq(gallery.name)
        expect(response.json['icons'].size).to eq(1)
        expect(response.json['icons'][0]['id']).to eq(gallery.icons.first.id)
      end
    end
  end
end
