RSpec.feature "Viewing posts", :type => :feature do
  scenario "with a user layout set" do
    user = login
    post = create(:post, user: user)

    visit post_path(post)
    expect(page).to have_xpath("//img[contains(@src, 'menu-')]")

    user.update!(layout: 'starrydark', avatar: create(:icon, user: user))
    visit post_path(post)
    expect(page).to have_xpath("//img[contains(@src, 'menugray-')]")
  end

  scenario "with an archived author" do
    user = create(:user)
    post = create(:post, user: user)
    reply = create(:reply, post: post)
    create(:reply, post: post, user: user)
    user.archive
    visit post_path(post)

    within('.post-post') do
      expect(page).to have_selector('.post-author', exact_text: '(deleted user)')
    end
    replies = page.all('.post-reply')
    within(replies[0]) do
      expect(page).to have_selector('.post-author', exact_text: reply.user.username)
    end
    within(replies[1]) do
      expect(page).to have_selector('.post-author', exact_text: '(deleted user)')
    end
  end

  context "with content warnings" do
    let(:warning) { create(:content_warning, name: 'violence') }
    let(:post) { create(:post, content_warnings: [warning]) }

    scenario "when user has content warnings turned on" do
      visit post_path(post)
      within('.error') do
        expect(page).to have_text('This post has the following content warnings')
        expect(page).to have_text('violence')
      end
    end

    scenario "when user has content warnings turned off" do
      user = login
      user.update(hide_warnings: true)
      visit post_path(post)
      expect(page).not_to have_selector('.error')
    end

    scenario "when user ignores warnings" do
      visit post_path(post, ignore_warnings: true)
      expect(page).not_to have_selector('.error')
    end
  end
end
