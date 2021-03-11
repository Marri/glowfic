RSpec.describe "Viewing a tag", type: :system do
  scenario "Viewing a setting" do
    # set up sample data
    setting_owner = create(:user, username: 'setting owner')
    setting = create(:setting, user: setting_owner, name: 'sample setting')
    first_user = create(:user, username: 'first user')
    second_user = create(:user, username: 'second user')
    untemplated_character = create(:character,
      user: first_user, settings: [setting],
      name: 'Test character', screenname: 'the-test', pb: 'Example Person')
    template = create(:template, user: second_user, name: 'sample template')
    templated_character = create(:character,
      user: second_user, template: template, settings: [setting],
      name: 'Templated character')

    create(:character, name: 'Other character') # this character must be missing

    # test expectations
    visit tag_path(setting)

    expect(page).to have_selector('.tag-info-box', text: 'Setting: sample setting')

    within(row_for('Owner')) do
      expect(page).to have_text('setting owner')
    end

    within('.tag-info-box') do
      click_link 'Characters'
    end

    row = find('tr', text: 'Test character')
    within(row) do
      expect(page).to have_link('Test character', href: character_path(untemplated_character))
      expect(page).to have_text('the-test')
      expect(page).to have_text('Example Person')
    end

    row = find('tr', text: 'Templated character')
    within(row) do
      expect(page).to have_link('Templated character', href: character_path(templated_character))
      expect(page).to have_link('sample template', href: template_path(template))
    end

    expect(page).not_to have_selector('tr', text: 'Other character')
  end
end
