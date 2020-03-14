RSpec.feature "Resetting password", :type => :feature do
  scenario "Resetting your password" do
    # request reset
    user = create(:user)
    visit new_password_reset_path
    expect(page).to have_selector("th.editor-title", exact_text: "Request Password Reset")
    within(".form-table") do
      fill_in "Username", with: user.username
      fill_in "Email address", with: user.email
      click_button "Reset Password"
    end
    expect(page).to have_selector('.success', exact_text: 'A password reset link has been emailed to you.')

    # complete reset request
    reset = PasswordReset.last
    visit password_reset_path(reset.auth_token)
    expect(page).to have_selector("th.editor-title", exact_text: "Change Password")
    fill_in "New Password", with: 'anewpass'
    fill_in "Confirm Password", with: 'anewpass'
    click_button "Save"
    expect(page).to have_selector('.success', exact_text: "Password changed.")
    expect(user.reload.authenticate('anewpass')).to be true
  end
end
