require "spec_helper"

RSpec.describe Api::V1::PostsController do
  describe "GET index" do
    shared_examples_for "index.json" do |in_doc|
      it "should support no search", show_in_doc: in_doc do
        post = create(:post)
        get :index
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(post.as_json(min: true).stringify_keys)
      end

      it "should support search", show_in_doc: in_doc do
        post = create(:post, subject: 'search')
        create(:post, subject: 'no') # post2
        get :index, params: { q: 'se' }
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(post.as_json(min: true).stringify_keys)
      end

      it "hides private posts" do
        create(:post, privacy: Concealable::PRIVATE)
        post = create(:post)
        get :index
        expect(response).to have_http_status(200)
        expect(response.json).to have_key('results')
        expect(response.json['results']).to contain_exactly(post.as_json(min: true).stringify_keys)
      end
    end

    context "when logged in" do
      before(:each) { login }

      it_behaves_like "index.json", false
    end

    context "when logged out" do
      it_behaves_like "index.json", true
    end
  end

  describe "GET show" do
    it "requires valid post", :show_in_doc do
      get :show, params: { id: 0 }
      expect(response).to have_http_status(404)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("Post could not be found.")
    end

    it "requires access to post", :show_in_doc do
      post = create(:post, privacy: Concealable::PRIVATE)
      get :show, params: { id: post.id }
      expect(response).to have_http_status(403)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "succeeds with valid post", :show_in_doc do
      post = create(:post, with_icon: true, with_character: true)
      get :show, params: { id: post.id }
      expect(response).to have_http_status(200)
      expect(response.json['id']).to eq(post.id)
      expect(response.json['num_replies']).to eq(0)
      expect(response.json['authors'].size).to eq(1)
      expect(response.json['authors'][0]['id']).to eq(post.user_id)
      expect(response.json['content']).to eq(post.content)
      expect(response.json['icon']['id']).to eq(post.icon_id)
      expect(response.json['character']['id']).to eq(post.character_id)
    end
  end

  describe "POST reorder" do
    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(401)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    context "without section_id" do
      it "requires a continuity you have access to" do
        continuity = create(:continuity)
        continuity_post1 = create(:post, continuity_id: continuity.id)
        continuity_post2 = create(:post, continuity_id: continuity.id)
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)

        post_ids = [continuity_post2.id, continuity_post1.id]

        login
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(403)
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
      end

      it "requires a single continuity without section_id" do
        user = create(:user)
        continuity1 = create(:continuity, creator: user)
        continuity2 = create(:continuity, creator: user)
        continuity_post1 = create(:post, continuity_id: continuity1.id)
        continuity_post2 = create(:post, continuity_id: continuity2.id)
        continuity_post3 = create(:post, continuity_id: continuity2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(0)
        expect(continuity_post3.reload.section_order).to eq(1)

        post_ids = [continuity_post3.id, continuity_post2.id, continuity_post1.id]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one continuity')
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(0)
        expect(continuity_post3.reload.section_order).to eq(1)
      end

      it "requires section_id if posts in section" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        section = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: section.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)

        post_ids = [continuity_post2.id, continuity_post1.id]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the continuity, or no section')
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
      end

      it "requires valid post_ids" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        post1 = create(:post, continuity_id: continuity.id)
        post2 = create(:post, continuity_id: continuity.id)
        expect(post1.reload.section_order).to eq(0)
        expect(post2.reload.section_order).to eq(1)

        post_ids = [-1]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
      end

      it "works for valid changes", :show_in_doc do
        continuity = create(:continuity)
        continuity2 = create(:continuity, creator: continuity.creator)
        continuity_post1 = create(:post, continuity_id: continuity.id)
        continuity_post2 = create(:post, continuity_id: continuity.id)
        continuity_post3 = create(:post, continuity_id: continuity.id)
        continuity_post4 = create(:post, continuity_id: continuity.id)
        continuity_post5 = create(:post, continuity_id: continuity2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
        expect(continuity_post3.reload.section_order).to eq(2)
        expect(continuity_post4.reload.section_order).to eq(3)
        expect(continuity_post5.reload.section_order).to eq(0)

        post_ids = [continuity_post3.id, continuity_post1.id, continuity_post4.id, continuity_post2.id]

        login_as(continuity.creator)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(continuity_post1.reload.section_order).to eq(1)
        expect(continuity_post2.reload.section_order).to eq(3)
        expect(continuity_post3.reload.section_order).to eq(0)
        expect(continuity_post4.reload.section_order).to eq(2)
        expect(continuity_post5.reload.section_order).to eq(0)
      end

      it "works when specifying valid subset", :show_in_doc do
        continuity = create(:continuity)
        continuity2 = create(:continuity, creator: continuity.creator)
        continuity_post1 = create(:post, continuity_id: continuity.id)
        continuity_post2 = create(:post, continuity_id: continuity.id)
        continuity_post3 = create(:post, continuity_id: continuity.id)
        continuity_post4 = create(:post, continuity_id: continuity.id)
        continuity_post5 = create(:post, continuity_id: continuity2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
        expect(continuity_post3.reload.section_order).to eq(2)
        expect(continuity_post4.reload.section_order).to eq(3)
        expect(continuity_post5.reload.section_order).to eq(0)

        post_ids = [continuity_post3.id, continuity_post1.id]

        login_as(continuity.creator)
        post :reorder, params: { ordered_post_ids: post_ids }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => [continuity_post3.id, continuity_post1.id, continuity_post2.id, continuity_post4.id]})
        expect(continuity_post1.reload.section_order).to eq(1)
        expect(continuity_post2.reload.section_order).to eq(2)
        expect(continuity_post3.reload.section_order).to eq(0)
        expect(continuity_post4.reload.section_order).to eq(3)
        expect(continuity_post5.reload.section_order).to eq(0)
      end
    end

    context "with section_id" do
      it "requires a continuity you have access to" do
        continuity = create(:continuity)
        section = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: section.id)
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)

        post_ids = [continuity_post2.id, continuity_post1.id]

        login
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(403)
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
      end

      it "requires a single section" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        subcontinuity1 = create(:subcontinuity, continuity_id: continuity.id)
        subcontinuity2 = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: subcontinuity1.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: subcontinuity2.id)
        continuity_post3 = create(:post, continuity_id: continuity.id, section_id: subcontinuity2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(0)
        expect(continuity_post3.reload.section_order).to eq(1)

        post_ids = [continuity_post3.id, continuity_post2.id, continuity_post1.id]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: subcontinuity1.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the continuity, or no section')
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(0)
        expect(continuity_post3.reload.section_order).to eq(1)
      end

      it "requires valid section id" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        section = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: section.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)

        post_ids = [continuity_post2.id, continuity_post1.id]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: 0 }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the continuity, or no section')
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
      end

      it "requires correct section id" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        subcontinuity1 = create(:subcontinuity, continuity_id: continuity.id)
        subcontinuity2 = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: subcontinuity1.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: subcontinuity2.id)
        continuity_post3 = create(:post, continuity_id: continuity.id, section_id: subcontinuity2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(0)
        expect(continuity_post3.reload.section_order).to eq(1)

        post_ids = [continuity_post3.id, continuity_post2.id]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: subcontinuity1.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the continuity, or no section')
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(0)
        expect(continuity_post3.reload.section_order).to eq(1)
      end

      it "requires no section_id if posts not in section" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        section = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id)
        continuity_post2 = create(:post, continuity_id: continuity.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)

        post_ids = [continuity_post2.id, continuity_post1.id]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(422)
        expect(response.json['errors'][0]['message']).to eq('Posts must be from one specified section in the continuity, or no section')
        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
      end

      it "requires valid post_ids" do
        user = create(:user)
        continuity = create(:continuity, creator: user)
        section = create(:subcontinuity, continuity_id: continuity.id)
        post1 = create(:post, continuity_id: continuity.id, section_id: section.id)
        post2 = create(:post, continuity_id: continuity.id, section_id: section.id)
        expect(post1.reload.section_order).to eq(0)
        expect(post2.reload.section_order).to eq(1)

        post_ids = [-1]
        login_as(user)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(404)
        expect(response.json['errors'][0]['message']).to eq('Some posts could not be found: -1')
      end

      it "works for valid changes", :show_in_doc do
        continuity = create(:continuity)
        section = create(:subcontinuity, continuity_id: continuity.id)
        section2 = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post3 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post4 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post5 = create(:post, continuity_id: continuity.id, section_id: section2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
        expect(continuity_post3.reload.section_order).to eq(2)
        expect(continuity_post4.reload.section_order).to eq(3)
        expect(continuity_post5.reload.section_order).to eq(0)

        post_ids = [continuity_post3.id, continuity_post1.id, continuity_post4.id, continuity_post2.id]

        login_as(continuity.creator)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => post_ids})
        expect(continuity_post1.reload.section_order).to eq(1)
        expect(continuity_post2.reload.section_order).to eq(3)
        expect(continuity_post3.reload.section_order).to eq(0)
        expect(continuity_post4.reload.section_order).to eq(2)
        expect(continuity_post5.reload.section_order).to eq(0)
      end

      it "works when specifying valid subset", :show_in_doc do
        continuity = create(:continuity)
        section = create(:subcontinuity, continuity_id: continuity.id)
        section2 = create(:subcontinuity, continuity_id: continuity.id)
        continuity_post1 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post2 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post3 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post4 = create(:post, continuity_id: continuity.id, section_id: section.id)
        continuity_post5 = create(:post, continuity_id: continuity.id, section_id: section2.id)

        expect(continuity_post1.reload.section_order).to eq(0)
        expect(continuity_post2.reload.section_order).to eq(1)
        expect(continuity_post3.reload.section_order).to eq(2)
        expect(continuity_post4.reload.section_order).to eq(3)
        expect(continuity_post5.reload.section_order).to eq(0)

        post_ids = [continuity_post3.id, continuity_post1.id]

        login_as(continuity.creator)
        post :reorder, params: { ordered_post_ids: post_ids, section_id: section.id }
        expect(response).to have_http_status(200)
        expect(response.json).to eq({'post_ids' => [continuity_post3.id, continuity_post1.id, continuity_post2.id, continuity_post4.id]})
        expect(continuity_post1.reload.section_order).to eq(1)
        expect(continuity_post2.reload.section_order).to eq(2)
        expect(continuity_post3.reload.section_order).to eq(0)
        expect(continuity_post4.reload.section_order).to eq(3)
        expect(continuity_post5.reload.section_order).to eq(0)
      end
    end
  end
end
