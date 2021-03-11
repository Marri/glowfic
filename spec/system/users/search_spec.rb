RSpec.describe "Searching users", :type => :system do
  scenario "Logged-out user searches simple list of users" do
    simple_user = create(:user, username: 'Test Alice')
    moietied_user = create(:user, username: 'Test Bob', moiety: 'FF0000', moiety_name: 'Test moiety')
    old_user = create(:user, username: 'Test Charlie', created_at: Time.zone.local(2018, 1, 1))
    create(:user, username: 'Dominique')

    visit search_users_path

    expect(page).to have_text("Search Users")

    def search_for(str)
      within('.search-form') do
        fill_in 'Username', with: str
        click_button 'Search'
      end
    end

    search_for('Fred')
    expect(page).to have_text("Total: 0")
    expect(page).not_to have_text('Test')
    expect(page).not_to have_text('Dominique')

    search_for('Test')
    expect(page).to have_text("Total: 3")
    within('.user-row:nth-child(1)') do
      expect(page).to have_link('Test Alice', href: user_path(simple_user))
    end
    within('.user-row:nth-child(2)') do
      expect(page).to have_link('Test Bob', href: user_path(moietied_user))
      expect(page).to have_selector("span[title='Test moiety']")
    end
    within('.user-row:nth-child(3)') do
      expect(page).to have_link('Test Charlie', href: user_path(old_user))
      expect(page).to have_text('Jan 01, 2018 12:00 AM')
    end
    expect(page).not_to have_text('Dominique')
  end
end
