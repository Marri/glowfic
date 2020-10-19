RSpec.describe AliasesController do
  include ActiveJob::TestHelper

  describe "GET new" do
    it "requires login" do
      get :new, params: { character_id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      user_id = login
      get :new, params: { character_id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires your character" do
      user = create(:user)
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      get :new, params: { character_id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("You do not have permission to modify this character.")
    end

    it "succeeds" do
      character = create(:character)
      login_as(character.user)
      get :new, params: { character_id: character.id }
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("New Alias: #{character.name}")
      expect(assigns(:alias)).to be_a_new_record
      expect(assigns(:alias).character).to eq(character)
    end
  end

  describe "POST create" do
    it "requires login" do
      post :create, params: { character_id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      user_id = login
      post :create, params: { character_id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires your character" do
      user = create(:user)
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      post :create, params: { character_id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("You do not have permission to modify this character.")
    end

    it "fails with missing params" do
      character = create(:character)
      login_as(character.user)
      post :create, params: { character_id: character.id }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Alias could not be created because of the following problems:")
      expect(assigns(:page_title)).to eq("New Alias: #{character.name}")
      expect(assigns(:alias)).to be_a_new_record
    end

    it "fails with invalid params" do
      character = create(:character)
      login_as(character.user)
      post :create, params: { character_id: character.id, character_alias: {name: ''} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Alias could not be created because of the following problems:")
      expect(assigns(:page_title)).to eq("New Alias: #{character.name}")
      expect(assigns(:alias)).to be_a_new_record
    end

    it "succeeds when valid" do
      expect(CharacterAlias.count).to eq(0)
      test_name = 'Test character alias'

      character = create(:character)
      login_as(character.user)

      post :create, params: { character_id: character.id, character_alias: {name: test_name} }

      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:success]).to eq("Alias created.")
      expect(CharacterAlias.count).to eq(1)
      expect(character.aliases.count).to eq(1)
      expect(assigns(:alias).name).to eq(test_name)
    end
  end

  describe "DELETE destroy" do
    it "requires login" do
      delete :destroy, params: { id: -1, character_id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      user_id = login
      delete :destroy, params: { id: -1, character_id: -1 }
      expect(response).to redirect_to(user_characters_url(user_id))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires your character" do
      user = create(:user)
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      delete :destroy, params: { id: -1, character_id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("You do not have permission to modify this character.")
    end

    it "requires valid alias" do
      character = create(:character)
      login_as(character.user)
      delete :destroy, params: { id: -1, character_id: character.id }
      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:error]).to eq("Alias could not be found.")
    end

    it "requires aliases to match character" do
      character = create(:character)
      calias = create(:alias)
      login_as(character.user)
      expect(character.id).not_to eq(calias.character_id)
      delete :destroy, params: { id: calias.id, character_id: character.id }
      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:error]).to eq("Alias could not be found for that character.")
    end

    it "succeeds" do
      calias = create(:alias)
      reply = create(:reply, user: calias.character.user, character: calias.character, character_alias: calias)
      draft = create(:reply_draft, user: calias.character.user, character: calias.character, character_alias: calias)
      login_as(calias.character.user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        delete :destroy, params: { id: calias.id, character_id: calias.character_id }
      end
      expect(response).to redirect_to(edit_character_url(calias.character))
      expect(flash[:success]).to eq("Alias removed.")
      expect(draft.reload.character_alias_id).to be_nil
      expect(reply.reload.character_alias_id).to be_nil
    end

    it "handles destroy failure" do
      calias = create(:alias)
      reply = create(:reply, user: calias.character.user, character: calias.character, character_alias: calias)
      login_as(calias.character.user)
      expect_any_instance_of(CharacterAlias).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: calias.id, character_id: calias.character.id }
      expect(response).to redirect_to(edit_character_path(calias.character))
      expect(flash[:error]).to eq("Alias could not be deleted.")
      expect(reply.reload.character_alias).to eq(calias)
    end
  end
end
