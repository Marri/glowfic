RSpec.describe "Listing users", :type => :system do
  scenario "Logged-out user views simple list of users" do
    simple_user = create(:user, username: 'Alice')
    moietied_user = create(:user, username: 'Bob', moiety: 'FF0000', moiety_name: 'Test moiety')
    old_user = create(:user, username: 'Charlie', created_at: Time.zone.local(2018, 1, 1))

    visit users_path

    expect(page).to have_text('Users')
    within('.user-row:nth-child(1)') do
      expect(page).to have_link('Alice', href: user_path(simple_user))
    end
    within('.user-row:nth-child(2)') do
      expect(page).to have_link('Bob', href: user_path(moietied_user))
      expect(page).to have_selector("span[title='Test moiety']")
    end
    within('.user-row:nth-child(3)') do
      expect(page).to have_link('Charlie', href: user_path(old_user))
      expect(page).to have_text('Jan 01, 2018 12:00 AM')
    end
  end
end
