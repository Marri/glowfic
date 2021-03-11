RSpec.describe "Creating a new index", :type => :system do
  scenario "Create a simple index" do
    login
    visit new_index_path
    expect(page).to have_no_selector('.flash.error')
    within('.form-table') do
      fill_in 'Index Name', with: 'Example index'
      click_button 'Save'
    end
    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_selector('.flash.success')
    within('.flash.success') do
      expect(page).to have_text('Index created!')
    end
  end
end
