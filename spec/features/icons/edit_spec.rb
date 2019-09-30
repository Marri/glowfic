require 'rails_helper'

RSpec.feature "Editing icons", type: :feature do
  let(:user) { create(:user, password: 'known') }

  before(:each) { login(user, 'known') }

  scenario "User edits their icon" do
    icon = create(:icon, user: user)

    visit icon_path(icon)
    expect(page).to have_selector('.icon-keyword', exact_text: icon.keyword)

    within('.icon-info-box') do
      click_link 'Edit Icon'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.form-table th', exact_text: 'Edit Icon')

    within("#edit_icon_#{icon.id}") do
      fill_in 'Credit', with: 'sample credit'
      fill_in 'URL', with: 'https://v.dreamwidth.org/933559/1081151'
    end

    click_button 'Save'

    expect(page).to have_selector('.success', exact_text: 'Icon updated.')
    expect(page).to have_selector('.icon-keyword', exact_text: icon.keyword)
    expect(page).to have_selector('.icon-credit', exact_text: 'sample credit')

    expect(page.find(".icon")[:src]).to eq('https://v.dreamwidth.org/933559/1081151')
  end

  scenario "User replaces a hotlinked icon with an uploaded one" do
    icon = create(:icon, user: user)

    visit icon_path(icon)
    expect(page).to have_selector('.icon-keyword', exact_text: icon.keyword)

    within('.icon-info-box') do
      click_link 'Edit Icon'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.form-table th', exact_text: 'Edit Icon')

    within("#edit_icon_#{icon.id}") do
      attach_file("icon[image]", Rails.root.join('app', 'assets', 'images', 'icons', 'add.png'))
    end

    click_button 'Save'

    expect(page).to have_selector('.success', exact_text: 'Icon updated.')
    expect(page).to have_selector('.icon-keyword', exact_text: icon.keyword)
    expect(icon.reload.image).to be_attached

    url = Rails.application.routes.url_helpers.rails_blob_url(icon.image)
    expect(page.find(".icon")[:src]).to eq(url)
  end

  scenario "User changes uploaded icon" do
    icon = create(:uploaded_icon, user: user)
    expect(icon.image).to be_attached
    checksum = icon.image.checksum

    visit icon_path(icon)
    expect(page).to have_selector('.icon-keyword', exact_text: icon.keyword)

    within('.icon-info-box') do
      click_link 'Edit Icon'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.form-table th', exact_text: 'Edit Icon')

    within("#edit_icon_#{icon.id}") do
      attach_file("icon[image]", Rails.root.join('app', 'assets', 'images', 'icons', 'add.png'))
    end

    click_button 'Save'

    expect(page).to have_selector('.success', exact_text: 'Icon updated.')
    expect(page).to have_selector('.icon-keyword', exact_text: icon.keyword)
    expect(icon.reload.image.checksum).not_to eq(checksum)

    url = Rails.application.routes.url_helpers.rails_blob_url(icon.image)
    expect(page.find(".icon")[:src]).to eq(url)
  end
end
