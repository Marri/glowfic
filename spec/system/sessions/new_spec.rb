# Sessions#new is primarily for mobile logins.
# The other flow is tested (implicitly) everywhere that uses the login method.
RSpec.describe "Logging in", :type => :system do
  scenario "Log in with invalid details" do
    visit login_path
    expect(page).to have_no_selector('.flash')
    within('.form-table') do
      fill_in 'Username', with: 'Invalid user'
      fill_in 'Password', with: 'failed password'
      click_on 'Sign In'
    end

    expect(page).to have_selector('.flash.error', text: 'That username does not exist.')
    expect(page).to have_current_path(login_path)

    username = 'Valid user'
    create(:user, username: username)
    within('.form-table') do
      fill_in 'Username', with: username
      fill_in 'Password', with: 'failed password'
      click_on 'Sign In'
    end

    expect(page).to have_selector('.flash.error', text: 'You have entered an incorrect password.')
    expect(page).to have_current_path(login_path)
  end

  scenario "Log in with valid details" do
    username = 'Test user'
    password = 'my password1234@'
    create(:user, username: username, password: password)
    visit login_path
    expect(page).to have_no_selector('.flash')

    expect(page).to have_selector('.form-table')
    within('.form-table') do
      fill_in 'Username', with: username
      fill_in 'Password', with: password
      click_on 'Sign In'
    end

    expect(page).to have_current_path(continuities_path)
    expect(page).to have_no_selector('.flash.error')
    expect(page).to have_selector('.flash.success', text: 'You are now logged in as Test user. Welcome back!')
    expect(page).to have_no_selector('#username')
    expect(page).to have_selector('#user-username', text: username)

    # make sure we're still logged in after navigating somewhere else
    visit root_path
    expect(page).to have_no_selector('.flash')
    expect(page).to have_no_selector('#username')
    expect(page).to have_selector('#user-username', text: username)
  end

  scenario "Error while already logged in" do
    login

    visit login_path
    expect(page).to have_current_path(continuities_path)
    expect(page).to have_selector('.flash.error', text: 'You are already logged in.')
    expect(page).to have_no_selector('#username')
  end
end
