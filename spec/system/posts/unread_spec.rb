RSpec.describe "Unread posts", :type => :system do
  scenario "User views their unread page" do
    visit unread_posts_path
    within(".error") { expect(page).to have_text("You must be logged in") }

    user = login
    visit unread_posts_path
    expect(page).to have_no_selector(".error")
    expect(page).to have_text("Unread Posts")
    expect(page).to have_text("No posts yet")

    create_list(:post, 2)
    3.times do
      unread = Timecop.freeze(Time.zone.now - 1.day) do
        unread = create(:post)
        unread.mark_read(user)
        unread
      end
      create(:reply, user: unread.user, post: unread)
    end
    4.times do
      read = create(:post)
      read.mark_read(user)
    end

    visit unread_posts_path
    expect(page).to have_selector('.post-subject', count: 5)
    expect(page).to have_xpath("//img[contains(@src, 'note')]")

    user.update!(layout: 'starrydark')
    click_link "Opened Threads »"
    expect(page).to have_selector('.post-subject', count: 3)
    expect(page).to have_xpath("//img[contains(@src, 'bullet')]")
  end
end
