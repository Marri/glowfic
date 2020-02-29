RSpec.describe AliasesController do
  include ActiveJob::TestHelper

  describe "GET new" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires login" do
      get :new, params: { character_id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      login_as(user)
      get :new, params: { character_id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires your character" do
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      get :new, params: { character_id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("That is not your character.")
    end

    it "succeeds" do
      login_as(user)
      get :new, params: { character_id: character.id }
      expect(response.status).to eq(200)
      expect(assigns(:page_title)).to eq("New Alias: #{character.name}")
      expect(assigns(:alias)).to be_a_new_record
      expect(assigns(:alias).character).to eq(character)
    end
  end

  describe "POST create" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires login" do
      post :create, params: { character_id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      login_as(user)
      post :create, params: { character_id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires your character" do
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      post :create, params: { character_id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("That is not your character.")
    end

    it "fails with missing params" do
      login_as(user)
      post :create, params: { character_id: character.id }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Alias could not be created.")
      expect(assigns(:page_title)).to eq("New Alias: #{character.name}")
      expect(assigns(:alias)).to be_a_new_record
    end

    it "fails with invalid params" do
      login_as(user)
      post :create, params: { character_id: character.id, character_alias: {name: ''} }
      expect(response.status).to eq(200)
      expect(flash[:error][:message]).to eq("Alias could not be created.")
      expect(assigns(:page_title)).to eq("New Alias: #{character.name}")
      expect(assigns(:alias)).to be_a_new_record
    end

    it "succeeds when valid" do
      expect(CharacterAlias.count).to eq(0)
      test_name = 'Test character alias'

      login_as(user)

      post :create, params: { character_id: character.id, character_alias: {name: test_name} }

      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:success]).to eq("Alias created.")
      expect(CharacterAlias.count).to eq(1)
      expect(character.aliases.count).to eq(1)
      expect(assigns(:alias).name).to eq(test_name)
    end
  end

  describe "DELETE destroy" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }

    it "requires login" do
      delete :destroy, params: { id: -1, character_id: -1 }
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid character" do
      login_as(user)
      delete :destroy, params: { id: -1, character_id: -1 }
      expect(response).to redirect_to(user_characters_url(user))
      expect(flash[:error]).to eq("Character could not be found.")
    end

    it "requires your character" do
      login_as(user)
      character = create(:character)
      expect(character.user_id).not_to eq(user.id)
      delete :destroy, params: { id: -1, character_id: character.id }
      expect(response).to redirect_to(user_characters_url(user.id))
      expect(flash[:error]).to eq("That is not your character.")
    end

    it "requires valid alias" do
      login_as(user)
      delete :destroy, params: { id: -1, character_id: character.id }
      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:error]).to eq("Alias could not be found.")
    end

    it "requires aliases to match character" do
      login_as(user)
      calias = create(:alias)
      expect(character.id).not_to eq(calias.character_id)
      delete :destroy, params: { id: calias.id, character_id: character.id }
      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:error]).to eq("Alias could not be found for that character.")
    end

    it "succeeds" do
      login_as(user)
      calias = create(:alias, character: character)
      reply = create(:reply, user: user, character: character, character_alias: calias)
      draft = create(:reply_draft, user: user, character: character, character_alias: calias)
      login_as(user)
      perform_enqueued_jobs(only: UpdateModelJob) do
        delete :destroy, params: { id: calias.id, character_id: character.id }
      end
      expect(response).to redirect_to(edit_character_url(character))
      expect(flash[:success]).to eq("Alias removed.")
      expect(draft.reload.character_alias_id).to be_nil
      expect(reply.reload.character_alias_id).to be_nil
    end

    it "handles destroy failure" do
      calias = create(:alias, character: character)
      reply = create(:reply, user: user, character: character, character_alias: calias)
      login_as(user)
      expect_any_instance_of(CharacterAlias).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'fake error')
      delete :destroy, params: { id: calias.id, character_id: character.id }
      expect(response).to redirect_to(edit_character_path(character))
      expect(flash[:error]).to eq({message: "Alias could not be deleted.", array: []})
      expect(reply.reload.character_alias).to eq(calias)
    end
  end
end
