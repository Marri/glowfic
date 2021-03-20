RSpec.describe Api::V1::RepliesController do
  describe "GET index" do
    it "requires valid post", :show_in_doc do
      get :index, params: { post_id: 0 }
      expect(response).to have_http_status(:not_found)
      expect(response.json['errors'].size).to eq(1)
      expect(response.json['errors'][0]['message']).to eq("Post could not be found.")
    end

    it "requires access to post", :show_in_doc do
      post = create(:post, privacy: :private)
      get :index, params: { post_id: post.id }
      expect(response).to have_http_status(:forbidden)
      expect(response.json['errors'][0]['message']).to eq("You do not have permission to perform this action.")
    end

    it "succeeds with valid post", :show_in_doc do
      post = create(:post, num_replies: 2, with_icon: true, with_character: true)
      calias = create(:alias)
      reply = create(:reply, post: post, user: calias.character.user, character: calias.character, character_alias: calias, with_icon: true)
      expect(calias.name).not_to eq(reply.character.name)
      get :index, params: { post_id: post.id }
      expect(response).to have_http_status(:ok)
      expect(response.json.size).to eq(3)
      expect(response.json[2]['id']).to eq(reply.id)
      expect(response.json[2]['icon']['id']).to eq(reply.icon_id)
      expect(response.json[2]['character']['id']).to eq(reply.character_id)
      expect(response.json[2]['character']['name']).to eq(calias.character.name)
      expect(response.json[2]['character_name']).to eq(calias.name)
    end

    it "paginates" do
      post = create(:post, num_replies: 5, with_icon: true, with_character: true)
      get :index, params: { post_id: post.id, per_page: 2, page: 3 }
      expect(response).to have_http_status(:ok)
      expect(response.headers['Per-Page'].to_i).to eq(2)
      expect(response.headers['Page'].to_i).to eq(3)
      expect(response.headers['Total'].to_i).to eq(5)
      expect(response.headers['Link']).not_to be_nil
      expect(response.json.size).to eq(1)
    end
  end
end
