RSpec.describe Api::V1::TemplatesController do
  describe "GET index" do
    def create_search_templates
      create(:template, name: 'baa') # firsttemplate
      create(:template, name: 'aba') # midtemplate
      create(:template, name: 'aab') # endtemplate
      create(:template, name: 'aaa') # nottemplate
      Template.all.each do |template|
        create(:template, name: "#{template.name.upcase}c")
      end
    end

    it "works logged in" do
      create_search_templates
      api_login
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.json['results'].count).to eq(8)
    end

    it "works logged out", show_in_doc: true do
      create_search_templates
      get :index, params: { q: 'b' }
      expect(response).to have_http_status(:ok)
      expect(response.json['results'].count).to eq(2)
    end

    it "raises error on invalid page", show_in_doc: true do
      get :index, params: { page: 'b' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "raises error on invalid user", show_in_doc: true do
      get :index, params: { user_id: 'b' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "raises error on not found user", show_in_doc: true do
      get :index, params: { user_id: '12' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "finds only user's templates", show_in_doc: true do
      user = create(:user)
      notuser = create(:user)
      template = create(:template, user: user)
      create(:template, user: notuser) # nottemplate

      get :index, params: { user_id: template.user_id }
      expect(response.json['results'].count).to eq(1)
    end
  end
end
