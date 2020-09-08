RSpec.describe TemplatesController do
  let(:user) { create(:user) }
  let(:template) { create(:template, user: user) }
  let(:char) { create(:character, user: user) }

  describe "GET new" do
    it "requires login" do
      get :new
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "works" do
      login
      get :new
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("New Template")
      expect(assigns(:template)).to be_a_new_record
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid params" do
      login
      post :create
      expect(response).to render_template(:new)
      expect(flash[:error][:message]).to eq("Your template could not be saved because of the following problems:")
      expect(flash[:error][:array]).to eq(["Name can't be blank"])
      expect(assigns(:page_title)).to eq("New Template")
      expect(assigns(:template)).not_to be_valid
      expect(assigns(:template)).to be_a_new_record
    end

    it "works" do
      login_as(user)
      post :create, params: { template: {name: 'testtest', description: 'test desc', character_ids: [char.id]} }
      created = Template.last
      expect(response).to redirect_to(template_url(created))
      expect(flash[:success]).to eq("Template saved successfully.")
      expect(created.name).to eq('testtest')
      expect(created.description).to eq('test desc')
      expect(created.characters).to match_array([char])
    end
  end

  describe "GET show" do
    it "requires valid template logged out" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("Template could not be found.")
    end

    it "requires valid template logged in" do
      user_id = login
      get :show, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Template could not be found.")
    end

    it "works logged in" do
      login
      get :show, params: { id: create(:template).id }
      expect(response).to have_http_status(200)
    end

    it "works logged out" do
      get :show, params: { id: create(:template).id }
      expect(response).to have_http_status(200)
    end

    it "sets correct variables" do
      template = create(:template, user: user)
      chars = create_list(:character, 2, user: user, template: template)
      non_char = create(:character)
      template_post = create(:post, user: user, character: chars[0])
      reply_post = create(:post)
      create(:reply, post: reply_post, user: user, character: chars[1])
      create(:post, character: non_char, user: non_char.user)

      get :show, params: { id: template.id }
      expect(assigns(:page_title)).to eq(template.name)
      expect(assigns(:posts).map(&:id)).to eq([reply_post.id, template_post.id])
      expect(assigns(:user)).to eq(template.user)
    end

    it "calculates OpenGraph meta" do
      user = create(:user, username: 'user')
      template = create(:template, name: 'template', user: user, description: "This is an example template.")
      create_list(:character, 3, template: template)

      get :show, params: { id: template.id }

      meta_og = assigns(:meta_og)
      expect(meta_og.keys).to match_array([:url, :title, :description])
      expect(meta_og[:url]).to eq(template_url(template))
      expect(meta_og[:title]).to eq('user » template')
      expect(meta_og[:description]).to eq("This is an example template.\n3 characters")
    end
  end

  describe "GET edit" do
    it "requires login" do
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid template" do
      user_id = login
      get :edit, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Template could not be found.")
    end

    it "requires your template" do
      user_id = login
      get :edit, params: { id: template.id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("That is not your template.")
    end

    it "works" do
      login_as(user)
      get :edit, params: { id: template.id }
      expect(response).to have_http_status(200)
      expect(assigns(:page_title)).to eq("Edit Template: #{template.name}")
      expect(assigns(:template)).to eq(template)
    end
  end

  describe "PUT update" do
    it "requires login" do
      put :update, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid template" do
      user_id = login
      put :update, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Template could not be found.")
    end

    it "requires your template" do
      user_id = login
      put :update, params: { id: template.id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("That is not your template.")
    end

    it "requires valid params" do
      login_as(user)
      put :update, params: { id: template.id, template: {name: ''} }
      expect(assigns(:template)).not_to be_valid
      expect(response).to render_template(:edit)
      expect(flash[:error][:message]).to eq("Your template could not be saved because of the following problems:")
      expect(flash[:error][:array]).to eq(["Name can't be blank"])
    end

    it "works" do
      new_name = template.name + 'new'
      login_as(user)

      put :update, params: {
        id: template.id,
        template: {
          name: new_name,
          description: 'new desc',
          character_ids: [char.id]
        }
      }
      expect(response).to redirect_to(template_url(template))
      expect(flash[:success]).to eq("Template saved successfully.")

      template.reload
      expect(template.name).to eq(new_name)
      expect(template.description).to eq('new desc')
      expect(template.characters).to match_array([char])
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid template" do
      user_id = login
      delete :destroy, params: { id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Template could not be found.")
    end

    it "requires your template" do
      user_id = login
      delete :destroy, params: { id: template.id }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("That is not your template.")
    end

    it "succeeds" do
      login_as(user)
      delete :destroy, params: { id: template.id }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:success]).to eq("Template deleted successfully.")
    end

    it "handles destroy failure" do
      char
      login_as(user)
      expect_any_instance_of(Template).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: template.id }
      expect(response).to redirect_to(template_url(template))
      expect(flash[:error]).to eq({message: "Template could not be deleted.", array: []})
      expect(char.reload.template).to eq(template)
    end
  end

  describe "#editor_setup" do
    it "orders untemplated characters correctly" do
      login_as(user)
      char2 = create(:character, user: user, name: 'b')
      char3 = create(:character, user: user, name: 'c')
      char1 = create(:character, user: user, name: 'a')
      controller.send(:editor_setup)
      expect(assigns(:selectable_characters)).to eq([char1, char2, char3])
    end

    it "has more tests" do
      skip
    end
  end
end
