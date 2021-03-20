RSpec.describe ContributeController do
  describe "GET index" do
    it "succeeds when logged out" do
      get :index
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Contribute")
    end

    it "succeeds when logged in" do
      login
      get :index
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Contribute")
    end
  end
end
