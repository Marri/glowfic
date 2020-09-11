RSpec.describe Api::V1::IndexPostsController do
  describe "POST reorder" do
    let(:user) { create(:user) }
    let(:index) { create(:index, user: user) }
    let(:index2) { create(:index, user: user) }

    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    context "without index_section_id" do
      it "requires a index you have access to" do
        posts = create_list(:index_post, 2, index: index)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        post_ids = posts.map(&:id).reverse

        api_login
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(403)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires a single index" do
        posts = [create(:index_post, index: index)]
        posts += create_list(:index_post, 2, index: index2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])

        post_ids = posts.map(&:id).reverse

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one index')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
      end

      it "requires index_section_id if posts in index_section" do
        index_section = create(:index_section, index: index)
        posts = create_list(:index_post, 2, index: index, index_section: index_section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])

        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires valid post_ids" do
        posts = create_list(:index_post, 2, index: index)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: [-1] }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "works for valid changes", :show_in_doc do
        posts = create_list(:index_post, 4, index: index)
        posts << create(:index_post, index: index2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0], posts[3], posts[1]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 3, 0, 2, 0])
      end

      it "works when specifying valid subset", :show_in_doc do
        posts = create_list(:index_post, 4, index: index)
        posts << create(:index_post, index: index2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => [posts[2], posts[0], posts[1], posts[3]].map(&:id)})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 2, 0, 3, 0])
      end
    end

    context "with index_section_id" do
      let(:section) { create(:index_section, index: index) }
      let(:section2) { create(:index_section, index: index) }

      it "requires a index you have access to" do
        posts = create_list(:index_post, 2, index: index, index_section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])

        post_ids = posts.map(&:id).reverse

        api_login
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(403)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires a single section" do
        posts = [create(:index_post, index: index, index_section: section)]
        posts += create_list(:index_post, 2, index: index, index_section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])

        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
      end

      it "requires valid section id" do
        posts = create_list(:index_post, 2, index: index, index_section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])

        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: 0 }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires correct section id" do
        posts = [create(:index_post, index: index, index_section: section)]
        posts += create_list(:index_post, 2, index: index, index_section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])

        post_ids = posts[1..2].map(&:id).reverse

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 0, 1])
      end

      it "requires no section_id if posts not in section" do
        posts = create_list(:index_post, 2, index: index)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])

        post_ids = posts.map(&:id).reverse
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "requires valid post_ids" do
        posts = create_list(:index_post, 2, index: index, index_section: section)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: [-1], section_id: section.id }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1])
      end

      it "works for valid changes", :show_in_doc do
        posts = create_list(:index_post, 4, index: index, index_section: section)
        posts << create(:index_post, index: index, index_section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0], posts[3], posts[1]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 3, 0, 2, 0])
      end

      it "works when specifying valid subset", :show_in_doc do
        posts = create_list(:index_post, 4, index: index, index_section: section)
        posts << create(:index_post, index: index, index_section: section2)
        expect(posts.map(&:reload).map(&:section_order)).to eq([0, 1, 2, 3, 0])

        post_ids = [posts[2], posts[0]].map(&:id)

        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => [posts[2], posts[0], posts[1], posts[3]].map(&:id)})
        expect(posts.map(&:reload).map(&:section_order)).to eq([1, 2, 0, 3, 0])
      end
    end
  end
end
