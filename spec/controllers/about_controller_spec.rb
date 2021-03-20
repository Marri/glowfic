RSpec.describe AboutController do
  describe "GET tos" do
    it "succeeds when logged out" do
      get :tos
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Terms of Service")
    end

    it "succeeds when logged in" do
      login
      get :tos
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Terms of Service")
    end

    it "does not show TOS prompt" do
      user = create(:user, tos_version: nil)
      login_as(user)
      get :tos
      expect(response).not_to render_template('about/accept_tos')
      expect(response).to render_template('about/tos')
    end
  end

  describe "GET privacy" do
    it "succeeds when logged out" do
      get :privacy
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Privacy Policy")
    end

    it "succeeds when logged in" do
      login
      get :privacy
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Privacy Policy")
    end

    it "does not show TOS prompt" do
      user = create(:user, tos_version: 0)
      login_as(user)
      get :privacy
      expect(response).not_to render_template('about/accept_tos')
    end
  end

  describe "GET dmca" do
    it "succeeds when logged out" do
      get :dmca
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("DMCA Policy")
    end

    it "succeeds when logged in" do
      login
      get :dmca
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("DMCA Policy")
    end

    it "does not show TOS prompt" do
      user = create(:user, tos_version: nil)
      login_as(user)
      get :dmca
      expect(response).not_to render_template('about/accept_tos')
    end
  end

  describe "GET contact" do
    it "succeeds when logged out" do
      get :contact
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Contact Us")
    end

    it "succeeds when logged in" do
      login
      get :contact
      expect(response).to have_http_status(:ok)
      expect(assigns(:page_title)).to eq("Contact Us")
    end

    it "does not show TOS prompt" do
      user = create(:user, tos_version: 20110709)
      login_as(user)
      get :contact
      expect(response).not_to render_template('about/accept_tos')
    end
  end
end
