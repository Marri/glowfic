RSpec.describe CharacterHelper do
  describe "#settings_info" do
    let (:user) { create(:user) }
    let (:character1) { create(:character, user: user) }
    let (:character2) { create(:character, user: user) }
    let (:setting1) { create(:setting, user: user) }
    let (:setting2) { create(:setting, user: user) }
    let (:association) { Character.where(id: [character1.id, character2.id]) }

    it "handles characters with no setting" do
      expect(helper.settings_info(association)).to eq({})
    end

    it "handles characters with one setting" do
      character1.update!(settings: [setting1])
      character2.update!(settings: [setting2])
      expected = {
        character1.id => [[setting1.id, setting1.name]],
        character2.id => [[setting2.id, setting2.name]]
      }
      expect(helper.settings_info(association)).to eq(expected)
    end

    it "handles characters with many settings" do
      character1.update!(settings: [setting1, setting2])
      association = Character.where(id: [character1.id])
      expected = { character1.id => [[setting1.id, setting1.name], [setting2.id, setting2.name]] }
      expect(helper.settings_info(association)).to eq(expected)
    end

    it "handles multiple characters with the same setting" do
      character1.update!(settings: [setting1])
      character2.update!(settings: [setting1])
      character3 = create(:character, user: user, settings: [setting1, setting2])
      association = Character.where(id: [character1.id, character2.id, character3.id])
      expected = {
        character1.id => [[setting1.id, setting1.name]],
        character2.id => [[setting1.id, setting1.name]],
        character3.id => [[setting1.id, setting1.name], [setting2.id, setting2.name]]
      }
      expect(helper.settings_info(association)).to eq(expected)
    end

    it "handles characters with a mixture of settings" do
      character1.update!(settings: [setting1])
      character2.update!(settings: [setting2])
      character3 = create(:character, user: user, settings: [setting1, setting2])
      character4 = create(:character, user: user)
      association = Character.where(id: [character1.id, character2.id, character3.id, character4.id])
      expected = {
        character1.id => [[setting1.id, setting1.name]],
        character2.id => [[setting2.id, setting2.name]],
        character3.id => [[setting1.id, setting1.name], [setting2.id, setting2.name]]
      }
      expect(helper.settings_info(association)).to eq(expected)
    end
  end

  describe "#character_list" do
    let (:user) { create(:user, username: 'John Doe') }

    describe "handles simple characters" do
      let (:character1) { create(:character, user: user, name: 'Test Character 1') }
      let (:character2) { create(:character, user: user, name: 'Test Character 2') }
      let (:assoc) { Character.where(id: [character1.id, character2.id]) }

      it "when not showing templates" do
        assoc = Character.where(id: [character1.id, character2.id])
        expected = [
          [character1.id, 'Test Character 1', nil, nil, nil, nil, user.id, 'John Doe', false],
          [character2.id, 'Test Character 2', nil, nil, nil, nil, user.id, 'John Doe', false]
        ]
        expect(helper.characters_list(assoc, false)).to match_array(expected)
      end

      it "when showing templates" do
        assoc = Character.where(id: [character1.id, character2.id])
        expected = [
          [character1.id, 'Test Character 1', nil, nil, nil, nil, user.id, 'John Doe', false, nil, nil],
          [character2.id, 'Test Character 2', nil, nil, nil, nil, user.id, 'John Doe', false, nil, nil]
        ]
        expect(helper.characters_list(assoc, true)).to match_array(expected)
      end

      it "with deleted users" do
        user.update!(deleted: true)
        expected = [
          [character1.id, 'Test Character 1', nil, nil, nil, nil, user.id, 'John Doe', true],
          [character2.id, 'Test Character 2', nil, nil, nil, nil, user.id, 'John Doe', true]
        ]
        expect(helper.characters_list(assoc, false)).to match_array(expected)
      end

      it "from multiple users" do
        user2 = create(:user, username: 'Jane Doe')
        character2.update!(user: user2)
        expected = [
          [character1.id, 'Test Character 1', nil, nil, nil, nil, user.id, 'John Doe', false],
          [character2.id, 'Test Character 2', nil, nil, nil, nil, user2.id, 'Jane Doe', false]
        ]
        expect(helper.characters_list(assoc, false)).to match_array(expected)
      end
    end

    describe "handles complex characters" do
      let (:template1) { create(:template, name: 'Test Template 1')}
      let (:template2) { create(:template, name: 'Test Template 2')}

      let (:character1) do
        create(:character, user: user, template: template1,
               name: 'Test Character 1', screenname: 'screenname_one',
               nickname: "Nickname 1", pb: "Facecast 1", cluster: 'Cluster 1')
      end

      let (:character2) do
        create(:character, user: user, template: template2,
               name: 'Test Character 2', screenname: 'screenname_two',
               nickname: "Nickname 2", pb: "Facecast 2", cluster: 'Cluster 2')
      end

      let (:assoc) { Character.where(id: [character1.id, character2.id]) }

      it "when showing templates" do
        expected = [
          [character1.id, 'Test Character 1', 'Nickname 1', 'screenname_one',
           'Facecast 1', 'Cluster 1', user.id, 'John Doe', false, template1.id, "Test Template 1"],
          [character2.id, 'Test Character 2', 'Nickname 2', 'screenname_two',
           'Facecast 2', 'Cluster 2', user.id, 'John Doe', false, template2.id, "Test Template 2"]
        ]
        expect(helper.characters_list(assoc, true)).to match_array(expected)
      end

      it "when not showing templates" do
        expected = [
          [character1.id, 'Test Character 1', 'Nickname 1', 'screenname_one', 'Facecast 1', 'Cluster 1', user.id, 'John Doe', false],
          [character2.id, 'Test Character 2', 'Nickname 2', 'screenname_two', 'Facecast 2', 'Cluster 2', user.id, 'John Doe', false]
        ]
        expect(helper.characters_list(assoc, false)).to match_array(expected)
      end
    end

    it "handles a mixture of characters" do
      templateless = create_list(:character, 3, user: user)
      templated = Array.new(3) { create(:character, user: user, template: create(:template)) }
      template = create(:template)
      one_template = create_list(:character, 3, user: user, template: template)
      deleted_user = create_list(:character, 1, user: create(:user, deleted: true))
      other_user = create_list(:character, 2, user: create(:user))
      characters = templateless + templated + one_template + deleted_user + other_user
      assoc = Character.where(id: characters.map(&:id))
      # rubocop:disable Layout/LineLength
      expected = [
        templateless.map{ |char| [char.id, char.name, nil, nil, nil, nil, user.id,      user.username,      false, nil,              nil] },
        templated.map   { |char| [char.id, char.name, nil, nil, nil, nil, user.id,      user.username,      false, char.template.id, char.template.name] },
        one_template.map{ |char| [char.id, char.name, nil, nil, nil, nil, user.id,      user.username,      false, template.id,      template.name] },
        deleted_user.map{ |char| [char.id, char.name, nil, nil, nil, nil, char.user.id, char.user.username, true,  nil,              nil] },
        other_user.map  { |char| [char.id, char.name, nil, nil, nil, nil, char.user.id, char.user.username, false, nil,              nil] },
      ].flatten(1)
      # rubocop:enable Layout/LineLength
      expect(helper.characters_list(assoc, true)).to match_array(expected)
    end
  end
end
