RSpec.feature "Creating replies", :type => :feature do
  scenario "User replies to own post" do
    user = login
    post = create(:post, user: user)

    visit post_path(post)
    expect(page).to have_selector('.post-container', count: 1)
    expect(page).to have_no_selector('.post-expander', text: 'Join Thread')
    expect(page).to have_selector('#post-editor')

    # preview first:
    within('#post-editor') do
      click_button 'Preview'
    end
    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Draft saved.')
    expect(page).to have_selector('#post-editor')

    # then save:
    within('#post-editor') do
      click_button 'Post'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Reply posted.')
    expect(page).to have_selector('.post-container', count: 2)
    within('.post-reply') do
      expect(page).to have_selector('.post-author', exact_text: user.username)
      expect(page).to have_no_selector('.post-icon')
      expect(page).to have_no_selector('.post-character')
      expect(page).to have_no_selector('.post-screenname')
    end

    # check author list
    visit stats_post_path(post)
    within(row_for('Authors')) do
      expect(page).to have_selector('a', count: 1)
      expect(page).to have_link(exact_text: user.username, href: user_path(user))
    end
  end

  scenario "User replies to open post" do
    post = create(:post)

    user = login
    visit post_path(post)
    expect(page).to have_selector('.post-container', count: 1)
    expect(page).to have_selector('.post-expander', text: 'Join Thread')
    expect(page).to have_selector('.hidden #post-editor')

    # TODO: use javascript to expand post editor
    within('#post-editor') do
      click_button 'Post'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Reply posted.')
    expect(page).to have_selector('.post-container', count: 2)
    within('.post-reply') do
      expect(page).to have_selector('.post-author', exact_text: user.username)
      expect(page).to have_no_selector('.post-icon')
      expect(page).to have_no_selector('.post-character')
      expect(page).to have_no_selector('.post-screenname')
    end

    # check author list
    visit stats_post_path(post)
    within(row_for('Authors')) do
      expect(page).to have_selector('a', count: 2)
      expect(page).to have_link(exact_text: post.user.username, href: user_path(post.user))
      expect(page).to have_link(exact_text: user.username, href: user_path(user))
    end
  end

  scenario "User tries to reply to locked post" do
    post = create(:post, authors_locked: true)

    login
    visit post_path(post)
    expect(page.text).not_to include('Join Thread')
    expect(page).to have_no_selector('#post-editor')
  end

  scenario "Logged-out user tries to reply to post" do
    post = create(:post)

    visit post_path(post)
    expect(page.text).not_to include('Join Thread')
    expect(page).to have_no_selector('#post-editor')
  end
end
