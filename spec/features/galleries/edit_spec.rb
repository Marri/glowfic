require 'spec_helper'

RSpec.feature "Editing galleries", type: :feature do
  scenario "User edits their gallery" do
    user = login
    gallery = create(:gallery, user: user, name: "test gallery", icon_count: 2)
    uploaded_icon = create(:uploaded_icon, user: user)
    gallery.icons << uploaded_icon
    expect(gallery.icons.last.image).to be_attached
    checksum = gallery.icons.last.image.checksum

    visit gallery_path(gallery)
    expect(page).to have_selector('.gallery-icon', count: 3)

    within('.gallery-header') do
      click_link 'Edit'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.gallery-edit-form th', exact_text: 'Edit Gallery')
    expect(page).to have_no_selector('.gallery-icon')

    within('.gallery-icons-edit') do
      expect(page).to have_selector('.gallery-icon-editor', count: 3)

      within first('.gallery-icon-editor') do
        expect(page).to have_selector("#icon-#{gallery.icons[0].id}")
        fill_in 'Credit', with: 'sample credit'
        fill_in 'URL', with: "https://v.dreamwidth.org/933559/1081151"
      end

      within all('.gallery-icon-editor')[1] do
        expect(page).to have_selector("#icon-#{gallery.icons[1].id}")
        attach_file("gallery[galleries_icons_attributes][1][icon_attributes][image]", Rails.root.join('app', 'assets', 'images', 'icons', 'add.png'))
      end

      within all('.gallery-icon-editor')[2] do
        expect(page).to have_selector("#icon-#{gallery.icons[2].id}")
        attach_file("gallery[galleries_icons_attributes][2][icon_attributes][image]", Rails.root.join('app', 'assets', 'images', 'icons', 'arrow_branch.png'))
      end
    end

    click_button 'Save'

    expect(page).to have_selector('.success', exact_text: 'Gallery saved.')
    expect(page).to have_selector('.gallery-edit-form th', exact_text: 'Edit Gallery')
    expect(gallery.icons[1].reload.image).to be_attached
    expect(gallery.icons[2].reload.image).to be_attached
    expect(gallery.icons[2].reload.image.checksum).not_to eq(checksum)

    within first('.gallery-icon-editor') do
      expect(page).to have_field('Credit', with: 'sample credit')
      expect(page).to have_field('URL', with: "https://v.dreamwidth.org/933559/1081151")
      expect(page.find("#icon-#{gallery.icons[0].id}")[:src]).to eq('https://v.dreamwidth.org/933559/1081151')
    end

    within all('.gallery-icon-editor')[1] do
      expect(page).to have_selector('.hidden.icon_url_field')
      url = Rails.application.routes.url_helpers.rails_blob_url(gallery.icons[1].image)
      expect(page.find("#icon-#{gallery.icons[1].id}")[:src]).to eq(url)
    end

    within all('.gallery-icon-editor')[2] do
      expect(page).to have_selector('.hidden.icon_url_field')
      url = Rails.application.routes.url_helpers.rails_blob_url(gallery.icons[2].image)
      expect(page.find("#icon-#{gallery.icons[2].id}")[:src]).to eq(url)
    end
  end
end
