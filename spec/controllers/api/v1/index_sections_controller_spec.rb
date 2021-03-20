RSpec.describe Api::V1::IndexSectionsController do
  describe "POST reorder" do
    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(:unauthorized)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "requires a index you have access to" do
      index = create(:index)
      index_section1 = create(:index_section, index_id: index.id)
      index_section2 = create(:index_section, index_id: index.id)
      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(1)

      section_ids = [index_section2.id, index_section1.id]

      api_login
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:forbidden)
      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(1)
    end

    it "requires a single index" do
      user = create(:user)
      index1 = create(:index, user: user)
      index2 = create(:index, user: user)
      index_section1 = create(:index_section, index_id: index1.id)
      index_section2 = create(:index_section, index_id: index2.id)
      index_section3 = create(:index_section, index_id: index2.id)

      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(0)
      expect(index_section3.reload.section_order).to eq(1)

      section_ids = [index_section3.id, index_section2.id, index_section1.id]
      api_login_as(user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.json['errors'][0]['message']).to eq('Sections must be from one index')
      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(0)
      expect(index_section3.reload.section_order).to eq(1)
    end

    it "requires valid section ids" do
      index = create(:index)
      index_section1 = create(:index_section, index_id: index.id)
      index_section2 = create(:index_section, index_id: index.id)
      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(1)
      section_ids = [-1]

      api_login_as(index.user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:not_found)
      expect(response.json['errors'][0]['message']).to eq('Some sections could not be found: -1')
      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(1)
    end

    it "works for valid changes", :show_in_doc do
      index = create(:index)
      index2 = create(:index, user: index.user)
      index_section1 = create(:index_section, index_id: index.id)
      index_section2 = create(:index_section, index_id: index.id)
      index_section3 = create(:index_section, index_id: index.id)
      index_section4 = create(:index_section, index_id: index.id)
      index_section5 = create(:index_section, index_id: index2.id)

      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(1)
      expect(index_section3.reload.section_order).to eq(2)
      expect(index_section4.reload.section_order).to eq(3)
      expect(index_section5.reload.section_order).to eq(0)

      section_ids = [index_section3.id, index_section1.id, index_section4.id, index_section2.id]

      api_login_as(index.user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({'section_ids' => section_ids})
      expect(index_section1.reload.section_order).to eq(1)
      expect(index_section2.reload.section_order).to eq(3)
      expect(index_section3.reload.section_order).to eq(0)
      expect(index_section4.reload.section_order).to eq(2)
      expect(index_section5.reload.section_order).to eq(0)
    end

    it "works when specifying valid subset", :show_in_doc do
      index = create(:index)
      index2 = create(:index, user: index.user)
      index_section1 = create(:index_section, index_id: index.id)
      index_section2 = create(:index_section, index_id: index.id)
      index_section3 = create(:index_section, index_id: index.id)
      index_section4 = create(:index_section, index_id: index.id)
      index_section5 = create(:index_section, index_id: index2.id)

      expect(index_section1.reload.section_order).to eq(0)
      expect(index_section2.reload.section_order).to eq(1)
      expect(index_section3.reload.section_order).to eq(2)
      expect(index_section4.reload.section_order).to eq(3)
      expect(index_section5.reload.section_order).to eq(0)

      section_ids = [index_section3.id, index_section1.id]

      api_login_as(index.user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({'section_ids' => [index_section3.id, index_section1.id, index_section2.id, index_section4.id]})
      expect(index_section1.reload.section_order).to eq(1)
      expect(index_section2.reload.section_order).to eq(2)
      expect(index_section3.reload.section_order).to eq(0)
      expect(index_section4.reload.section_order).to eq(3)
      expect(index_section5.reload.section_order).to eq(0)
    end
  end
end
