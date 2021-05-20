RSpec.describe Api::V1::IndexSectionsController do
  describe "POST reorder" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:index2) { create(:index, user: user) }

    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "requires a index you have access to" do
      sections = create_list(:index_section, 2, index: index)
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 1])
      section_ids = sections.map(&:id).reverse
      api_login
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(403)
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 1])
    end

    it "requires a single index" do
      sections = [create(:index_section, index: index)]
      sections += create_list(:index_section, 2, index: index2)
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 0, 1])

      section_ids = sections.map(&:id).reverse
      api_login_as(user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(422)
      expect(response.json['errors'][0]['message']).to eq('Sections must be from one index')
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
    end

    it "requires valid section ids" do
      sections = create_list(:index_section, 2, index: index)
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 1])
      api_login_as(user)
      post :reorder, params: { ordered_section_ids: [-1] }
      expect(response).to have_http_status(404)
      expect(response.json['errors'][0]['message']).to eq('Some sections could not be found: -1')
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 1])
    end

    it "works for valid changes", :show_in_doc do
      sections = create_list(:index_section, 4, index: index)
      sections << create(:index_section, index: index2)
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

      section_ids = [sections[2], sections[0], sections[3], sections[1]].map(&:id)

      api_login_as(user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(200)
      expect(response.json).to eq({'section_ids' => section_ids})
      expect(sections.map(&:reload).map(&:section_order)).to eq([1, 3, 0, 2, 0])
    end

    it "works when specifying valid subset", :show_in_doc do
      sections = create_list(:index_section, 4, index: index)
      sections << create(:index_section, index: index2)
      expect(sections.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

      section_ids = [sections[2], sections[0]].map(&:id)

      api_login_as(user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(200)
      expect(response.json).to eq({'section_ids' => [sections[2], sections[0], sections[1], sections[3]].map(&:id)})
      expect(sections.map(&:reload).map(&:section_order)).to eq([1, 2, 0, 3, 0])
    end
  end
end
