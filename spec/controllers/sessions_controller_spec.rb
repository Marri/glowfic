RSpec.describe SessionsController do
  describe "GET index" do
    it "works when logged out" do
      get :index
      expect(response.status).to eq(200)
      expect(controller.gon.logged_in).not_to eq(true)
    end

    it "works when logged in" do
      login
      get :index
      expect(response).to have_http_status(200)
      expect(controller.gon.logged_in).to eq(true)
    end

    it "does not show TOS prompt" do
      user = create(:user, tos_version: nil)
      login_as(user)
      get :index
      expect(response).not_to render_template('about/accept_tos')
    end

    it "logs out if user has become invalid" do
      user = create(:user)
      login_as(user)
      user.destroy!
      get :index
      expect(controller.send(:logged_in?)).not_to eq(true)
    end
  end

  describe "GET new" do
    it "works when logged out" do
      get :new
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("Sign In")
    end

    it "redirects when logged in" do
      login
      get :new
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You are already logged in.")
    end
  end

  describe "POST create" do
    let(:password) { 'password' }
    let(:user) { create(:user, password: password) }

    it "redirects when logged in" do
      login
      post :create
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You are already logged in.")
    end

    it "requires an existing username" do
      nonusername = 'nonuser'
      expect(User.find_by(username: nonusername)).to be_nil
      post :create, params: { username: nonusername }
      expect(flash[:error]).to eq("That username does not exist.")
      expect(controller.send(:logged_in?)).not_to eq(true)
    end

    it "requires unsuspended user" do
      user.update!(role: :suspended)
      post :create, params: { username: user.username }
      expect(flash[:error]).to eq("You could not be logged in.")
      expect(controller.send(:logged_in?)).not_to eq(true)
    end

    it "disallows logins with old passwords when reset is pending" do
      create(:password_reset, user: user)
      expect(user.password_resets.active.unused).not_to be_empty
      post :create, params: { username: user.username }
      expect(flash[:error]).to eq("The password for this account has been reset. Please check your email.")
      expect(controller.send(:logged_in?)).not_to eq(true)
    end

    it "requires a valid password" do
      post :create, params: { username: user.username, password: password + "-not" }
      expect(flash[:error]).to eq("You have entered an incorrect password.")
      expect(controller.send(:logged_in?)).not_to eq(true)
    end

    it "logs in successfully with salt_uuid" do
      expect(session[:user_id]).to be_nil
      expect(controller.send(:logged_in?)).not_to eq(true)

      post :create, params: { username: user.username, password: password }

      expect(session[:user_id]).to eq(user.id)
      expect(controller.send(:logged_in?)).to eq(true)
      expect(flash[:success]).to eq("You are now logged in as #{user.username}. Welcome back!")
      expect(cookies.signed[:user_id]).to be_nil
    end

    it "logs in successfully without salt_uuid and sets it" do
      user = create(:user)
      user.update_columns(salt_uuid: nil, crypted: user.send(:old_crypted_password, password)) # rubocop:disable Rails/SkipsModelValidations
      user.reload
      expect(user.salt_uuid).to be_nil
      expect(session[:user_id]).to be_nil
      expect(controller.send(:logged_in?)).not_to eq(true)

      post :create, params: { username: user.username, password: password }

      expect(session[:user_id]).to eq(user.id)
      expect(controller.send(:logged_in?)).to eq(true)
      expect(flash[:success]).to eq("You are now logged in as #{user.username}. Welcome back!")
      expect(cookies.signed[:user_id]).to be_nil
      expect(user.reload.salt_uuid).not_to be_nil
      expect(user.authenticate(password)).to eq(true)
    end

    it "creates permanent cookies when remember me is provided" do
      expect(cookies.signed[:user_id]).to be_nil
      post :create, params: { username: user.username, password: password, remember_me: true }
      expect(controller.send(:logged_in?)).to eq(true)
      expect(cookies.signed[:user_id]).to eq(user.id)
    end

    it "disallows logins from deleted users" do
      user.update!(deleted: true)
      post :create, params: { username: user.username }
      expect(flash[:error]).to eq("That username does not exist.")
      expect(controller.send(:logged_in?)).not_to eq(true)
    end
  end

  describe "PATCH confirm_tos" do
    it "redirects when logged in" do
      login
      patch :confirm_tos
      expect(response).to redirect_to(continuities_url)
      expect(flash[:error]).to eq("You are already logged in.")
    end

    it "creates cookie" do
      expect(cookies[:accepted_tos]).to be_nil
      patch :confirm_tos
      expect(response).to redirect_to(root_url)
      expect(cookies[:accepted_tos]).to eq(User::CURRENT_TOS_VERSION)
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "logs out" do
      login
      delete :destroy
      expect(controller.send(:logged_in?)).not_to eq(true)
      expect(flash[:success]).to eq("You have been logged out.")
      # TODO test session vars and cookies and redirect
    end
  end

  describe "#cookie_hash" do
    let(:user) { create(:user) }

    it "uses the correct host for staging" do
      without_partial_double_verification do
        allow(request).to receive(:host).and_return('glowfic-staging.herokuapp.com')
      end
      hash = {value: user.id, domain: 'glowfic-staging.herokuapp.com'}
      expect(controller.send(:cookie_hash, user.id)).to eq(hash)
    end

    it "uses the correct host for production" do
      without_partial_double_verification do
        allow(Rails.env).to receive(:production?).and_return(true)
      end
      hash = {value: user.id, domain: '.glowfic.com', tld_length: 2}
      expect(controller.send(:cookie_hash, user.id)).to eq(hash)
    end

    it "doesn't set a host otherwise" do
      expect(controller.send(:cookie_hash, user.id)).to eq({value: user.id})
    end
  end
end
