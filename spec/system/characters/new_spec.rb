RSpec.describe "Creating a new character", :type => :system do
  scenario "Create an invalid character", js: true do
    # view new character form without being logged in
    visit new_character_path
    expect(page).to have_selector('.flash.error')
    within('.flash.error') do
      expect(page).to have_text("You must be logged in")
    end

    # view new character form with no icons
    user = login
    visit new_character_path
    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_no_text("You must be logged in")
    expect(page).to have_selector("th", text: "New Character")
    expect(page).to have_no_selector("img.icon")

    # view new character form with icons
    create_list(:icon, 2, user: user)
    create(:icon, user: user, keyword: 'Example icon')
    visit new_character_path
    expect(page).to have_selector("img.icon", count: 3)

    # create character with no name
    find("img[alt='Example icon']").click
    expect(page).to have_selector('.selected-icon')
    expect(find('.selected-icon')[:alt]).to eq('Example icon')

    within('.form-table') do
      fill_in 'Template Nickname', with: 'Example nickname'
      fill_in 'Screen Name', with: 'example_screenname'
      fill_in 'Facecast', with: 'Example facecast'
      fill_in 'Description', with: 'Example description'
      click_button 'Save'
    end

    expect(page).to have_selector('.flash.error')
    within('.flash.error') do
      expect(page).to have_text('Your character could not be saved.')
      expect(page).to have_text('Name can\'t be blank')
    end

    # check that it preserved inputs
    expect(page).to have_selector('.selected-icon')
    expect(find('.selected-icon')[:alt]).to eq('Example icon')

    within('.form-table') do
      expect(page).to have_field('Template Nickname', with: 'Example nickname')
      expect(page).to have_field('Screen Name', with: 'example_screenname')
      expect(page).to have_field('Facecast', with: 'Example facecast')
      expect(page).to have_field('Description', with: 'Example description')
    end
  end

  scenario "Create a simple character" do
    login
    visit new_character_path
    expect(page).to have_no_selector('.flash.error')
    within('.form-table') do
      fill_in 'Character Name', with: 'Example character'
      click_button 'Save'
    end
    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_selector('.flash.success')
    within('.flash.success') do
      expect(page).to have_text('Character saved successfully.')
    end
  end

  scenario "Creating character with icon, description and extant template", js: true do
    user = login
    create_list(:icon, 2, user: user)
    icon = create(:icon, user: user, keyword: 'Example icon')
    template = create(:template, user: user, name: 'Example template')
    create(:template, user: user)
    visit new_character_path(template_id: template.id)

    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_selector('#select2-character_template_id-container', text: 'Example template')

    find("img[alt='Example icon']").click
    within('.form-table') do
      fill_in 'Character Name', with: 'Example character'
      fill_in 'Template Nickname', with: 'Example nickname'
      fill_in 'Screen Name', with: 'example_screenname'
      fill_in 'Facecast', with: 'Example facecast'
      fill_in 'Description', with: 'Example description'
      click_button 'Save'
    end
    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_selector('.flash.success')
    within('.flash.success') do
      expect(page).to have_text('Character saved successfully.')
    end

    within('.character-info-box') do
      expect(page).to have_selector('.character-name', text: 'Example character')
      expect(page).to have_selector('.character-screenname', text: 'example_screenname')
      expect(page).to have_selector('.character-icon')

      within('.character-icon') do
        expect(page).to have_selector("a[href='/icons/#{icon.id}']")
        expect(find('img')[:alt]).to eq('Example icon')
      end
    end

    within('.character-right-content-box') do
      expect(page).to have_selector('.character-template', text: 'Example template')
      expect(page).to have_selector('.character-pb', text: 'Example facecast')
      expect(page).to have_selector('.character-description', text: 'Example description')
    end
  end

  scenario "Creating character with new template" do
    login
    visit new_character_path
    expect(page).to have_no_selector('.flash.error')
    within('.form-table') do
      fill_in 'Character Name', with: 'Example character'
      check 'new_template'
      fill_in 'Template Name', with: 'Example template'
      click_button 'Save'
    end
    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_selector('.flash.success')
    within('.flash.success') do
      expect(page).to have_text('Character saved successfully.')
    end
    expect(page).to have_selector('.character-template', text: 'Example template')
  end
end
