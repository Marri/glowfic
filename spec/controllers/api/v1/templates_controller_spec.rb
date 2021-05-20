RSpec.describe Api::V1::TemplatesController do
  describe "GET index" do
    def create_search_templates
      names = ['baa', 'aba', 'aab', 'aaa']
      names.each {|name| create(:template, name: name) }
      names.each {|name| create(:template, name: name.upcase + 'c') }
    end

    it "works logged in" do
      create_search_templates
      api_login
      get :index
      expect(response).to have_http_status(200)
      expect(response.json['results'].count).to eq(8)
    end

    it "works logged out", show_in_doc: true do
      create_search_templates
      get :index, params: { q: 'b' }
      expect(response).to have_http_status(200)
      expect(response.json['results'].count).to eq(2)
    end

    it "raises error on invalid page", show_in_doc: true do
      get :index, params: { page: 'b' }
      expect(response).to have_http_status(422)
    end

    it "raises error on invalid user", show_in_doc: true do
      get :index, params: { user_id: 'b' }
      expect(response).to have_http_status(422)
    end

    it "raises error on not found user", show_in_doc: true do
      get :index, params: { user_id: '12' }
      expect(response).to have_http_status(422)
    end

    it "finds only user's templates", show_in_doc: true do
      template = create(:template)
      create(:template)

      get :index, params: { user_id: template.user_id }
      expect(response.json['results'].count).to eq(1)
    end
  end
end
