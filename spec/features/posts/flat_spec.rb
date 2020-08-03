RSpec.feature "Viewing flat posts", :type => :feature do
  scenario "User views a flat post" do
    user = login
    post = create(:post, user: user, subject: "test subject", content: "test content")

    GenerateFlatPostJob.perform_now(post.id)

    visit post_path(post, view: 'flat')
    expect(page).to have_selector('.post-container', count: 1)
    expect(page).to have_selector('.post-reply', count: 1)
    expect(page).to have_selector('#post-title', exact_text: "test subject")

    within('.post-content') do
      expect(page).to have_selector('p', exact_text: 'test content')
    end
  end
end
