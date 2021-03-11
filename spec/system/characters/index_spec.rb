RSpec.describe "Listing characters", type: :system do
  def with_template(characters, template)
    {
      template: template,
      characters: characters.map do |d|
        create(:character, d.merge(user: template.user, template: template))
      end,
    }
  end

  def without_template(characters)
    {
      characters: characters.map { |d| create(:character, d.merge(user: user)) },
    }
  end

  let!(:user) { create(:user, username: 'Sample user') }
  let!(:templates) {
    data = [
      { name: 'template 1' },
      { name: 'template 2' },
    ]
    data.map { |d| create(:template, d.merge(user: user)) }
  }

  let!(:earth) { create(:setting, name: 'Earth') }
  let!(:icon) { create(:icon, user: user, url: 'https://example.org/sample.png') }

  let!(:ungrouped_character_data) do
    [
      with_template([
        { name: 'Test character' },
        { name: 'Nicknamed', nickname: 'Other name' },
        { name: 'Character with screenname', screenname: 'test-screenname' },
        { name: 'Played by', pb: 'Test Person' },
        { name: 'With setting', settings: [earth] },
        { name: 'Iconned', default_icon: icon },
      ], templates.first),
      with_template([
        { name: 'Second template character' },
      ], templates.last),
      without_template([
        { name: 'Untemplated character' },
      ]),
    ]
  end

  before(:each) do
    create(:template, name: 'Unrelated template') # unrelated template
    create(:character, name: 'Unrelated character') # unrelated character
  end

  def expect_character_rows(characters)
    characters.each do |character|
      row = find('tr', text: character.name)
      within(row) do
        expect(page).to have_link(character.name, href: character_path(character))
        [:nickname, :screenname, :pb].each do |param|
          val = character.public_send(param)
          expect(page).to have_text(val) if val.present?
        end
        character.settings.each do |setting|
          expect(page).to have_link(setting.name, href: tag_path(setting))
        end
      end
    end
  end

  RSpec.shared_examples "characters#index" do |has_groups|
    def check_headers(group_data, has_groups)
      if has_groups
        text = if group_data[:group]
          'Group: ' + group_data[:group].name
        else
          'Ungrouped Characters'
        end
        expect(page).to have_selector('tr', text: text)
      end

      group_data[:templates].each do |data|
        text = if data[:template]
          'Template: ' + data[:template].name
        else
          'No Template'
        end
        expect(page).to have_selector('tr', text: text)
      end
    end

    def no_headers
      expect(page).not_to have_text('Template:')
      expect(page).not_to have_text('Group:')
    end

    def no_unrelated
      expect(page).not_to have_text('Unrelated template')
      expect(page).not_to have_text('Unrelated character')
      expect(page).not_to have_text('Unrelated group')
    end

    scenario "Viewing in list mode, separated by template" do
      visit user_characters_path(user_id: user.id, view: 'list', character_split: 'template')
      expect(page).to have_text("Sample user's Characters")

      no_unrelated

      groups.each do |group_data|
        check_headers(group_data, has_groups)
        group_data[:templates].each do |data|
          expect_character_rows(data[:characters])
        end
      end
    end

    scenario "Viewing in list mode, unseparated" do
      visit user_characters_path(user_id: user.id, view: 'list', character_split: 'none')
      expect(page).to have_text("Sample user's Characters")

      no_unrelated
      no_headers

      groups.each do |group_data|
        group_data[:templates].each do |data|
          expect_character_rows(data[:characters])
        end
      end
    end

    def expect_character_icons(characters)
      characters.each do |character|
        link = find_link(character.name, href: character_path(character))
        within(link) do
          expect(page).to have_text(character.screenname) if character.screenname.present?
          icon = character.default_icon
          next unless icon.present?

          img = find('img')
          expect(img[:src]).to eq(icon.url)
          expect(img[:alt]).to eq(icon.keyword)
          expect(img[:title]).to eq(icon.keyword)
        end
      end
    end

    scenario "Viewing in icon mode, separated by template" do
      visit user_characters_path(user_id: user.id, view: 'icon', character_split: 'template')
      expect(page).to have_text("Sample user's Characters")

      no_unrelated

      groups.each do |group_data|
        check_headers(group_data, has_groups)
        group_data[:templates].each do |data|
          expect_character_icons(data[:characters])
        end
      end
    end

    scenario "Viewing in icon mode, unseparated" do
      visit user_characters_path(user_id: user.id, view: 'icon', character_split: 'none')
      expect(page).to have_text("Sample user's Characters")

      no_unrelated
      no_headers

      groups.each do |group_data|
        group_data[:templates].each do |data|
          expect_character_icons(data[:characters])
        end
      end
    end
  end

  context "without character groups" do
    let!(:groups) do # rubocop:disable RSpec/LetSetup
      [
        {
          group: nil,
          templates: ungrouped_character_data,
        }
      ]
    end

    include_examples "characters#index", false
  end

  context "with character groups" do
    def grouped_sample(group)
      template = create(:template, user: user, name: 'grouped template')
      [
        with_template([
          { name: 'character group character 1', character_group: group },
        ], template),
        without_template([
          { name: 'grouped untemplated character', character_group: group },
        ]),
      ]
    end

    let!(:groups) do # rubocop:disable RSpec/LetSetup
      group = create(:character_group, user: user, name: 'test character group')
      [
        {
          group: group,
          templates: grouped_sample(group),
        },
        {
          group: nil,
          templates: ungrouped_character_data,
        }
      ]
    end

    include_examples "characters#index", true
  end
end
