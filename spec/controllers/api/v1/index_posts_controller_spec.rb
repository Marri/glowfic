RSpec.describe Api::V1::IndexPostsController do
  describe "POST reorder" do
    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(:unauthorized)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    context "without index_section_id" do
      it "requires a index you have access to" do
        index = create(:index)
        index_post1 = create(:index_post, index_id: index.id)
        index_post2 = create(:index_post, index_id: index.id)
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)

        post_ids = [index_post2.id, index_post1.id]

        api_login
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(:forbidden)
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
      end

      it "requires a single index without index_section_id" do
        user = create(:user)
        index1 = create(:index, user: user)
        index2 = create(:index, user: user)
        index_post1 = create(:index_post, index_id: index1.id)
        index_post2 = create(:index_post, index_id: index2.id)
        index_post3 = create(:index_post, index_id: index2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(0)
        expect(index_post3.reload.section_order).to eq(1)

        post_ids = [index_post3.id, index_post2.id, index_post1.id]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one index')
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(0)
        expect(index_post3.reload.section_order).to eq(1)
      end

      it "requires index_section_id if posts in index_section" do
        user = create(:user)
        index = create(:index, user: user)
        index_section = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)

        post_ids = [index_post2.id, index_post1.id]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
      end

      it "requires valid post_ids" do
        user = create(:user)
        index = create(:index, user: user)
        post1 = create(:index_post, index_id: index.id)
        post2 = create(:index_post, index_id: index.id)
        expect(post1.reload.section_order).to eq(0)
        expect(post2.reload.section_order).to eq(1)

        post_ids = [-1]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(:not_found)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
      end

      it "works for valid changes", :show_in_doc do
        index = create(:index)
        index2 = create(:index, user: index.user)
        index_post1 = create(:index_post, index_id: index.id)
        index_post2 = create(:index_post, index_id: index.id)
        index_post3 = create(:index_post, index_id: index.id)
        index_post4 = create(:index_post, index_id: index.id)
        index_post5 = create(:index_post, index_id: index2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
        expect(index_post3.reload.section_order).to eq(2)
        expect(index_post4.reload.section_order).to eq(3)
        expect(index_post5.reload.section_order).to eq(0)

        post_ids = [index_post3.id, index_post1.id, index_post4.id, index_post2.id]

        api_login_as(index.user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(:ok)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(index_post1.reload.section_order).to eq(1)
        expect(index_post2.reload.section_order).to eq(3)
        expect(index_post3.reload.section_order).to eq(0)
        expect(index_post4.reload.section_order).to eq(2)
        expect(index_post5.reload.section_order).to eq(0)
      end

      it "works when specifying valid subset", :show_in_doc do
        index = create(:index)
        index2 = create(:index, user: index.user)
        index_post1 = create(:index_post, index_id: index.id)
        index_post2 = create(:index_post, index_id: index.id)
        index_post3 = create(:index_post, index_id: index.id)
        index_post4 = create(:index_post, index_id: index.id)
        index_post5 = create(:index_post, index_id: index2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
        expect(index_post3.reload.section_order).to eq(2)
        expect(index_post4.reload.section_order).to eq(3)
        expect(index_post5.reload.section_order).to eq(0)

        post_ids = [index_post3.id, index_post1.id]

        api_login_as(index.user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(:ok)
        expect(response.json).to eq({'post_ids' => [index_post3.id, index_post1.id, index_post2.id, index_post4.id]})
        expect(index_post1.reload.section_order).to eq(1)
        expect(index_post2.reload.section_order).to eq(2)
        expect(index_post3.reload.section_order).to eq(0)
        expect(index_post4.reload.section_order).to eq(3)
        expect(index_post5.reload.section_order).to eq(0)
      end
    end

    context "with index_section_id" do
      it "requires a index you have access to" do
        index = create(:index)
        index_section = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)

        post_ids = [index_post2.id, index_post1.id]

        api_login
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section.id }
        expect(response).to have_http_status(:forbidden)
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
      end

      it "requires a single section" do
        user = create(:user)
        index = create(:index, user: user)
        index_section1 = create(:index_section, index_id: index.id)
        index_section2 = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section1.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section2.id)
        index_post3 = create(:index_post, index_id: index.id, index_section_id: index_section2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(0)
        expect(index_post3.reload.section_order).to eq(1)

        post_ids = [index_post3.id, index_post2.id, index_post1.id]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section1.id }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(0)
        expect(index_post3.reload.section_order).to eq(1)
      end

      it "requires valid section id" do
        user = create(:user)
        index = create(:index, user: user)
        index_section = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)

        post_ids = [index_post2.id, index_post1.id]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: 0 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
      end

      it "requires correct section id" do
        user = create(:user)
        index = create(:index, user: user)
        index_section1 = create(:index_section, index_id: index.id)
        index_section2 = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section1.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section2.id)
        index_post3 = create(:index_post, index_id: index.id, index_section_id: index_section2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(0)
        expect(index_post3.reload.section_order).to eq(1)

        post_ids = [index_post3.id, index_post2.id]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section1.id }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(0)
        expect(index_post3.reload.section_order).to eq(1)
      end

      it "requires no section_id if posts not in section" do
        user = create(:user)
        index = create(:index, user: user)
        index_section = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id)
        index_post2 = create(:index_post, index_id: index.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)

        post_ids = [index_post2.id, index_post1.id]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section.id }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the index, or no section')
        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
      end

      it "requires valid post_ids" do
        user = create(:user)
        index = create(:index, user: user)
        index_section = create(:index_section, index_id: index.id)
        post1 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        post2 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        expect(post1.reload.section_order).to eq(0)
        expect(post2.reload.section_order).to eq(1)

        post_ids = [-1]
        api_login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section.id }
        expect(response).to have_http_status(:not_found)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
      end

      it "works for valid changes", :show_in_doc do
        index = create(:index)
        index_section = create(:index_section, index_id: index.id)
        index_section2 = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post3 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post4 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post5 = create(:index_post, index_id: index.id, index_section_id: index_section2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
        expect(index_post3.reload.section_order).to eq(2)
        expect(index_post4.reload.section_order).to eq(3)
        expect(index_post5.reload.section_order).to eq(0)

        post_ids = [index_post3.id, index_post1.id, index_post4.id, index_post2.id]

        api_login_as(index.user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section.id }
        expect(response).to have_http_status(:ok)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(index_post1.reload.section_order).to eq(1)
        expect(index_post2.reload.section_order).to eq(3)
        expect(index_post3.reload.section_order).to eq(0)
        expect(index_post4.reload.section_order).to eq(2)
        expect(index_post5.reload.section_order).to eq(0)
      end

      it "works when specifying valid subset", :show_in_doc do
        index = create(:index)
        index_section = create(:index_section, index_id: index.id)
        index_section2 = create(:index_section, index_id: index.id)
        index_post1 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post2 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post3 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post4 = create(:index_post, index_id: index.id, index_section_id: index_section.id)
        index_post5 = create(:index_post, index_id: index.id, index_section_id: index_section2.id)

        expect(index_post1.reload.section_order).to eq(0)
        expect(index_post2.reload.section_order).to eq(1)
        expect(index_post3.reload.section_order).to eq(2)
        expect(index_post4.reload.section_order).to eq(3)
        expect(index_post5.reload.section_order).to eq(0)

        post_ids = [index_post3.id, index_post1.id]

        api_login_as(index.user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: index_section.id }
        expect(response).to have_http_status(:ok)
        expect(response.json).to eq({'post_ids' => [index_post3.id, index_post1.id, index_post2.id, index_post4.id]})
        expect(index_post1.reload.section_order).to eq(1)
        expect(index_post2.reload.section_order).to eq(2)
        expect(index_post3.reload.section_order).to eq(0)
        expect(index_post4.reload.section_order).to eq(3)
        expect(index_post5.reload.section_order).to eq(0)
      end
    end
  end
end
