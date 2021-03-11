RSpec.describe "Creating replies", :type => :system do
  def find_reply_on_page(reply)
    find('.post-reply') { |x| x.has_selector?('a', id: "reply-#{reply.id}") }
  end

  scenario "Logged-out user tries to edit a reply" do
    reply = create(:reply)

    visit reply_path(reply)
    within(find_reply_on_page(reply)) do
      expect(page).to have_no_link('Edit')
    end

    visit edit_reply_path(reply)
    expect(page).to have_selector('.error', text: 'You must be logged in to view that page.')
    expect(page).to have_current_path(root_path)
    expect(page).to have_no_selector('#post-editor')
  end

  scenario "User edits a reply" do
    user = create(:user, password: 'known')
    reply = create(:reply, user: user, content: 'example text')

    login(user, 'known')

    visit reply_path(reply)
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      click_link 'Edit'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.content-header', exact_text: 'Edit post')
    expect(page).to have_no_selector('.post-container')
    within('#post-editor') do
      fill_in 'reply_content', with: 'other text'
      click_button 'submit_button'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Post updated')
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      expect(page).to have_selector('.post-content', exact_text: 'other text')
    end
  end

  scenario "User edits a reply with preview" do
    user = create(:user, password: 'known')
    reply = create(:reply, user: user, content: 'example text')

    login(user, 'known')

    visit reply_path(reply)
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      click_link 'Edit'
    end

    # first changes, then preview
    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.content-header', exact_text: 'Edit post')
    expect(page).to have_no_selector('.post-container')
    within('#post-editor') do
      fill_in 'reply_content', with: 'other text'
      click_button 'Preview'
    end

    # verify preview, change again
    expect(page).to have_no_selector('.error')
    expect(page).to have_no_selector('.success')
    expect(page).to have_selector('.content-header', exact_text: reply.post.subject)
    expect(page).to have_selector('.post-container', count: 1)
    within('.post-container') do
      expect(page).to have_selector('.post-content', exact_text: 'other text')
    end

    within('#post-editor') do
      expect(page).to have_field('reply_content', with: 'other text')
      fill_in 'reply_content', with: 'third text'
      click_button 'submit_button'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Post updated')
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      expect(page).to have_selector('.post-content', exact_text: 'third text')
    end
  end

  scenario "User tries to edit someone else's reply" do
    reply = create(:reply, content: 'example text')

    login
    visit reply_path(reply)
    within(find_reply_on_page(reply)) do
      expect(page).to have_no_link('Edit')
    end

    visit edit_reply_path(reply)
    expect(page).to have_selector('.error', text: 'You do not have permission to modify this post.')
    expect(page).to have_current_path(post_path(reply.post))
  end

  scenario "Moderator edits a reply" do
    user = create(:user, password: 'known')
    reply = create(:reply, user: user, content: 'example text')

    login(create(:mod_user, password: 'known'), 'known')

    visit reply_path(reply)
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      click_link 'Edit'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.content-header', exact_text: 'Edit post')
    expect(page).to have_no_selector('.post-container')
    within('#post-editor') do
      fill_in 'reply_content', with: 'other text'
      fill_in 'Moderator note', with: 'example edit'
      click_button 'Save'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Post updated')
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      expect(page).to have_selector('.post-content', exact_text: 'other text')
      expect(page).to have_selector('.post-author', exact_text: user.username)
    end
  end

  scenario "Moderator edits a reply with preview" do
    user = create(:user, password: 'known')
    reply = create(:reply, user: user, content: 'example text')

    login(create(:mod_user, password: 'known'), 'known')

    visit reply_path(reply)
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      click_link 'Edit'
    end

    # first changes, then preview
    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.content-header', exact_text: 'Edit post')
    expect(page).to have_no_selector('.post-container')
    within('#post-editor') do
      fill_in 'reply_content', with: 'other text'
      fill_in 'Moderator note', with: 'example edit'
      click_button 'Preview'
    end

    # verify preview, change again
    expect(page).to have_no_selector('.error')
    expect(page).to have_no_selector('.success')
    expect(page).to have_selector('.content-header', exact_text: reply.post.subject)
    expect(page).to have_selector('.post-container', count: 1)
    within('.post-container') do
      expect(page).to have_selector('.post-content', exact_text: 'other text')
      expect(page).to have_selector('.post-author', exact_text: user.username)
    end

    within('#post-editor') do
      expect(page).to have_field('reply_content', with: 'other text')
      expect(page).to have_field('Moderator note', with: 'example edit')
      fill_in 'reply_content', with: 'third text'
      fill_in 'Moderator note', with: 'another edit'
      click_button 'Save'
    end

    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', exact_text: 'Post updated')
    expect(page).to have_selector('.post-container', count: 2)
    within(find_reply_on_page(reply)) do
      expect(page).to have_selector('.post-content', exact_text: 'third text')
      expect(page).to have_selector('.post-author', exact_text: user.username)
    end
  end
end
